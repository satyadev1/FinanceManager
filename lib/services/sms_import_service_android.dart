import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:indian_sms_filter/indian_sms_filter.dart';

import '../engine/sms_classifier.dart';
import '../models/sms_message.dart';
import '../models/transaction.dart';
import 'sms_import_result.dart';

const _uuid = Uuid();
const _channel = MethodChannel('com.example.finance_manager/sms');

/// Indian SMS plugin for TRAI sender map and region-specific logic.
final _indianPlugin = IndianSmsPlugin.instance;

bool get isSmsImportSupported => Platform.isAndroid;

Future<bool> requestSmsPermission() async {
  if (!Platform.isAndroid) return false;
  final current = await Permission.sms.status;
  if (current.isGranted) return true;
  final status = await Permission.sms.request();
  return status.isGranted;
}

Future<SmsImportResult> importFromSms() async {
  if (!Platform.isAndroid) {
    return const SmsImportResult(notSupported: true);
  }

  try {
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    debugPrint('[SMS-Android] Reading SMS from last 3 months via native channel...');

    final List<dynamic> raw = await _channel.invokeMethod('getInboxSms', {
      'sinceMs': threeMonthsAgo.millisecondsSinceEpoch,
    });

    debugPrint('[SMS-Android] Got ${raw.length} messages');

    final rawMessages = raw.cast<Map<dynamic, dynamic>>();
    final counts = <SmsCategory, int>{};
    final allMessages = <SmsMessageModel>[];
    final transactions = <Transaction>[];
    final accountMap = <String, DetectedAccount>{};
    final seen = <String>{};

    final amountPattern = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{2})?)|([\d,]+(?:\.\d{2})?)\s*(?:Rs\.?|INR|₹)',
      caseSensitive: false,
    );
    final debitKeywords = RegExp(
      r'\b(?:debited|withdrawn|spent|payment|purchase|deducted)\b',
      caseSensitive: false,
    );
    final creditKeywords = RegExp(
      r'\b(?:credited|deposited|received|refund)\b',
      caseSensitive: false,
    );

    for (final m in rawMessages) {
      final body = (m['body'] as String?) ?? '';
      final address = (m['address'] as String?) ?? '';
      final dateMs = m['date'] as int? ?? 0;
      if (body.trim().isEmpty) continue;

      SmsAnalysisResult analysis = analyzeSms(
        body,
        senderAddress: address,
        regionPlugin: _indianPlugin,
      );
      // TRAI boost: known bank sender + amount + txn keywords → treat as bank transaction
      if (_indianPlugin.shouldBoostToBankTransaction(analysis, body, address)) {
        analysis = SmsAnalysisResult(
          category: SmsIntentCategory.bankTransaction,
          riskScore: 10,
          phishingLikelihood: 0.05,
          reasoning: 'Known bank sender + amount + transaction keywords.',
          entities: analysis.entities,
        );
      }
      final cat = intentToLegacyCategory(analysis.category);
      counts[cat] = (counts[cat] ?? 0) + 1;

      final entities = analysis.entities;
      String? bankName = entities['bank_name'] as String?;
      bankName ??= _indianPlugin.getBankNameFromSender(address);
      final accountLast4 = entities['account_last_four'] as String?;
      final accountType = entities['account_type'] as String?;
      final amount = entities['amount'] as double?;
      final txType = entities['transaction_type'] as String?;
      final balance = entities['balance'] as double?;
      final txDateStr = entities['transaction_date'] as String?;

      DateTime date = dateMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(dateMs)
          : DateTime.now();
      if (txDateStr != null) {
        final parsed = DateTime.tryParse(txDateStr);
        if (parsed != null) date = parsed;
      }

      allMessages.add(SmsMessageModel(
        address: address,
        body: body,
        date: date,
        category: cat,
        bankName: bankName,
        accountLast4: accountLast4,
        accountType: accountType,
        amount: amount,
        transactionType: txType,
      ));

      // Broker transaction: create transaction with category 'broker'
      if (analysis.category == SmsIntentCategory.brokerTransaction) {
        final brokerAmount = entities['amount'] as double?;
        if (brokerAmount != null && brokerAmount > 0) {
          final brokerTxType = (entities['transaction_type'] as String?) == 'CREDIT' ? 'credit' : 'debit';
          final brokerTxKey = 'broker_${date.millisecondsSinceEpoch}_${brokerAmount}_$brokerTxType';
          if (!seen.contains(brokerTxKey)) {
            seen.add(brokerTxKey);
            final script = entities['script'] as String?;
            final orderId = entities['order_id'] as String?;
            final title = script != null
                ? 'Trading: $script'
                : (orderId != null ? 'Order $orderId' : _shortTitle(body));
            transactions.add(Transaction(
              id: _uuid.v4(),
              title: title,
              amount: brokerAmount,
              type: brokerTxType,
              date: date,
              source: 'sms',
              category: 'broker',
              createdAt: date,
            ));
          }
        }
        continue;
      }

      if (cat != SmsCategory.bankTransaction) continue;

      // Build transaction
      final amountMatch = amountPattern.firstMatch(body);
      if (amountMatch == null) continue;
      final amountStr = (amountMatch[1] ?? amountMatch[2]) ?? '';
      final parsedAmount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0;
      if (parsedAmount <= 0) continue;

      final isCredit = creditKeywords.hasMatch(body) && !debitKeywords.hasMatch(body);
      final type = isCredit ? 'credit' : 'debit';

      final txKey = '${date.millisecondsSinceEpoch}_${parsedAmount}_$type';
      if (seen.contains(txKey)) continue;
      seen.add(txKey);

      final merchant = entities['merchant'] as String? ?? entities['payee_name'] as String?;
      final title = (merchant != null && merchant.trim().isNotEmpty)
          ? merchant.trim()
          : _shortTitle(body, merchantFromBody: _extractMerchantFromBody(body));
      final isFastag = RegExp(
        r'\b(?:fastag|fast\s+tag|toll|nhai|toll\s+plaza)\b',
        caseSensitive: false,
      ).hasMatch(body) || RegExp(r'\b(?:fastag|fast\s+tag|toll)\b', caseSensitive: false).hasMatch(title);
      final upperAddress = address.toUpperCase();
      final isBenefits = RegExp(r'\b(?:pluxee|sodexo|zeta)\b', caseSensitive: false).hasMatch(body) ||
          upperAddress.contains('PLUXEE') || upperAddress.contains('SODEXO') || upperAddress.contains('ZETA');

      // Build detected account for bank only (not for FASTag/benefits – those get dedicated accounts below)
      if (!isFastag && !isBenefits && (accountLast4 != null || bankName != null)) {
        final key = '${accountLast4 ?? "unknown"}_${bankName?.toLowerCase() ?? "unknown"}';
        if (!accountMap.containsKey(key)) {
          final isCard = accountType == 'credit_card' || accountType == 'debit_card' || accountType == 'card';
          accountMap[key] = DetectedAccount(
            id: _uuid.v4(),
            lastFour: accountLast4,
            type: isCard ? 'card' : 'bank',
            subType: accountType,
            bankName: bankName,
            balance: balance,
          );
        }
        final da = accountMap[key]!;
        da.transactionCount++;
        if (balance != null) da.balance = balance;
      }

      // FASTag and benefits are separate from bank: use dedicated accounts, not bank accountId
      String? accountId;
      String? category;
      if (isFastag) {
        category = 'fastag';
        const fastagKey = 'fastag_account';
        if (!accountMap.containsKey(fastagKey)) {
          accountMap[fastagKey] = DetectedAccount(
            id: _uuid.v4(),
            lastFour: null,
            type: 'bank',
            subType: 'fastag',
            bankName: 'FASTag',
            name: 'FASTag',
            balance: null,
            transactionCount: 0,
            selected: true,
          );
        }
        accountId = accountMap[fastagKey]!.id;
        accountMap[fastagKey]!.transactionCount++;
      } else if (isBenefits) {
        category = 'benefits';
        const benefitsKey = 'benefits_account';
        if (!accountMap.containsKey(benefitsKey)) {
          accountMap[benefitsKey] = DetectedAccount(
            id: _uuid.v4(),
            lastFour: null,
            type: 'card',
            subType: 'benefits',
            bankName: 'Pluxee / Sodexo / Zeta',
            name: 'Benefits (Pluxee/Sodexo/Zeta)',
            balance: null,
            transactionCount: 0,
            selected: true,
          );
        }
        accountId = accountMap[benefitsKey]!.id;
        accountMap[benefitsKey]!.transactionCount++;
      } else {
        if (accountLast4 != null || bankName != null) {
          final key = '${accountLast4 ?? "unknown"}_${bankName?.toLowerCase() ?? "unknown"}';
          accountId = accountMap[key]?.id;
        }
      }

      transactions.add(Transaction(
        id: _uuid.v4(),
        title: title,
        amount: parsedAmount,
        type: type,
        date: date,
        source: 'sms',
        accountId: accountId,
        category: category,
        createdAt: date,
      ));
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));
    final detectedAccounts = accountMap.values.toList();
    for (final da in detectedAccounts) {
      if (da.name.isEmpty) da.name = da.displayName;
    }

    debugPrint('[SMS-Android] Parsed ${transactions.length} transactions, ${detectedAccounts.length} accounts from ${allMessages.length} messages');

    return SmsImportResult(
      transactions: transactions,
      detectedAccounts: detectedAccounts,
      messages: allMessages,
      messageCount: raw.length,
      classificationCounts: counts.isEmpty ? null : counts,
    );
  } on PlatformException catch (e) {
    debugPrint('[SMS-Android] PlatformException: ${e.code} - ${e.message}');
    if (e.code == 'PERMISSION_DENIED') {
      return const SmsImportResult(permissionDenied: true);
    }
    return SmsImportResult(error: e.message ?? e.code);
  } catch (e) {
    debugPrint('[SMS-Android] Exception: $e');
    return SmsImportResult(error: e.toString());
  }
}

String _shortTitle(String body, {String? merchantFromBody}) {
  if (merchantFromBody != null && merchantFromBody.trim().isNotEmpty) {
    return merchantFromBody.trim().length <= 60
        ? merchantFromBody.trim()
        : '${merchantFromBody.trim().substring(0, 60)}…';
  }
  const max = 60;
  final cleaned = body
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'(?:Rs\.?|INR|₹)\s*[\d,]+(?:\.\d{2})?'), '')
      .trim();
  if (cleaned.length <= max) return cleaned;
  return '${cleaned.substring(0, max)}…';
}

/// Extract merchant/payee from body when entities lack it (Indian patterns).
String? _extractMerchantFromBody(String body) {
  final toMatch = RegExp(
    r'(?:paid\s+to|to|transferred\s+to|received\s+from|at)\s+([A-Z][A-Za-z0-9\s]{0,35}?)(?:\s+\.|\s+via|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  final posMatch = RegExp(
    r'(?:at|@)\s*POS\s+([A-Za-z0-9\s]{2,50}?)(?:\s+\.|\s+on|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  final merchant = toMatch?.group(1)?.trim() ?? posMatch?.group(1)?.trim();
  if (merchant != null &&
      merchant.isNotEmpty &&
      merchant.length <= 50 &&
      !RegExp(r'^\d+$').hasMatch(merchant)) {
    return merchant;
  }
  return null;
}
