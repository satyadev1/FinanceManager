/// Enterprise-grade SMS Intelligence Engine.
/// Classifies intent, extracts entities, assigns risk, and returns structured JSON.
///
/// Region-specific logic (TRAI, UPI, etc.) is provided via [SmsRegionPlugin] from
/// the [indian_sms_filter] package.
import 'package:indian_sms_filter/indian_sms_filter.dart';

export 'package:indian_sms_filter/indian_sms_filter.dart'
    show SmsAnalysisResult, SmsIntentCategory, SmsRegionContext, SmsRegionPlugin;

/// Default region plugin used when none is provided. Set to [IndianSmsPlugin.instance]
/// for Indian SMS, or null for generic (no region) behavior.
SmsRegionPlugin? _defaultRegionPlugin;

/// Registers the default region plugin for [analyzeSms]. Call at app startup.
void registerSmsRegionPlugin(SmsRegionPlugin? plugin) {
  _defaultRegionPlugin = plugin;
}

/// Performs step-by-step analysis and returns structured result.
/// [senderAddress]: optional sender (e.g. TRAI AD-HDFCBK). Used by region plugins.
/// [regionPlugin]: optional plugin for region-specific filtering. Uses default if null.
SmsAnalysisResult analyzeSms(
  String message, {
  String? senderAddress,
  SmsRegionPlugin? regionPlugin,
}) {
  final body = message.trim();
  final lower = body.toLowerCase();
  final plugin = regionPlugin ?? _defaultRegionPlugin;
  final region = plugin?.getContext(senderAddress) ?? SmsRegionContext.none;

  if (body.isEmpty) {
    return SmsAnalysisResult(
      category: SmsIntentCategory.unknown,
      riskScore: 0,
      phishingLikelihood: 0,
      reasoning: 'Empty message.',
      entities: {},
    );
  }

  // 0️⃣ Region pre-filter (e.g. TRAI personal sender → skip)
  if (plugin != null) {
    final pre = plugin.preFilter(body, senderAddress);
    if (pre != null) return pre;
  }
  if (region.skipDeepParsing) {
    return const SmsAnalysisResult(
      category: SmsIntentCategory.unknown,
      riskScore: 0,
      phishingLikelihood: 0,
      reasoning: 'Personal sender; skipped deep parsing.',
      entities: {},
    );
  }

  // 1️⃣ AUTHENTICATION CHECK → OTP
  final otpResult = _checkOtp(lower, body);
  if (otpResult != null) return otpResult;

  // 2️⃣ Region: promotional prefix → try promotional first
  if (region.tryPromotionalFirst) {
    final promoResult = _checkPromotional(lower, body);
    if (promoResult != null) return promoResult;
  }

  // 3️⃣ FINANCIAL TRANSACTION CHECK → BANK_TRANSACTION
  final txnResult = _checkBankTransaction(lower, body, senderAddress, region);
  if (txnResult != null) {
    var result = txnResult;
    if (plugin != null) {
      result = plugin.postProcess(result, body, senderAddress);
    }
    return result;
  }

  // 4️⃣ BROKER TRANSACTION (trading: order executed, funds, demat)
  final brokerTxnResult = _checkBrokerTransaction(lower, body);
  if (brokerTxnResult != null) return brokerTxnResult;

  // 5️⃣ BANK BUT NOT TRANSACTIONAL
  final bankNonTxnResult = _checkBankNonTransactional(lower, body);
  if (bankNonTxnResult != null) return bankNonTxnResult;

  // 6️⃣ BROKER NON-TRANSACTIONAL (IPO, corporate action, alerts)
  final brokerNonTxnResult = _checkBrokerNonTransactional(lower, body);
  if (brokerNonTxnResult != null) return brokerNonTxnResult;

  // 7️⃣ REGULATORY (SEBI, RBI)
  final regulatoryResult = _checkRegulatory(lower, body);
  if (regulatoryResult != null) return regulatoryResult;

  // 8️⃣ PROMOTIONAL
  final promoResult = _checkPromotional(lower, body);
  if (promoResult != null) return promoResult;

  // 9️⃣ PHISHING (before generic spam)
  final phishingResult = _checkPhishing(lower, body);
  if (phishingResult != null) return phishingResult;

  // 🔟 SPAM
  final spamResult = _checkSpam(lower, body);
  if (spamResult != null) return spamResult;

  // 1️⃣1️⃣ SERVICE NOTIFICATION
  final serviceResult = _checkServiceNotification(lower, body);
  if (serviceResult != null) return serviceResult;

  // 1️⃣2️⃣ PERSONAL
  final personalResult = _checkPersonal(lower, body);
  if (personalResult != null) return personalResult;

  var result = SmsAnalysisResult(
    category: SmsIntentCategory.unknown,
    riskScore: 20,
    phishingLikelihood: 0,
    reasoning: 'No matching intent; treated as unknown.',
    entities: {},
  );
  if (plugin != null) {
    result = plugin.postProcess(result, body, senderAddress);
  }
  return result;
}

SmsAnalysisResult? _checkOtp(String lower, String body) {
  final otpWords = RegExp(
    r'\b(?:otp|verification\s+code|one-?time\s+password|login\s+code|'
    r'auth(?:entication)?\s+code|verify\s+code|one\s+time\s+password|'
    r'otp\s+is|code\s+is|valid\s+for\s+\d+\s*min)\b',
    caseSensitive: false,
  );
  if (!otpWords.hasMatch(lower)) return null;

  // Don't treat as OTP if it looks like a transaction (ref number, debited/credited)
  if (RegExp(r'\b(?:debited|credited|ref\s*no|reference|transaction|upi\s+ref)\b', caseSensitive: false).hasMatch(lower)) {
    return null;
  }

  final codeStyle = RegExp(r'code\s*[:\-]?\s*(\d{4,8})\b', caseSensitive: false).firstMatch(body);
  final codeMatch = RegExp(r'\b(\d{4,8})\b').firstMatch(body);
  final code = codeStyle?.group(1) ?? codeMatch?.group(1);
  if (code == null) return null;
  // Prefer 4–6 digit OTP; 8+ digit might be ref number
  if (code.length > 8) return null;

  final validityMatch = RegExp(r'valid\s+for\s+(\d+)\s*min', caseSensitive: false).firstMatch(lower);
  final serviceMatch = RegExp(r'(?:from|by|for)\s+([A-Za-z0-9\s]+?)(?:\s+\.|\s+valid|\.|$)', caseSensitive: false).firstMatch(body);

  int? validityMin;
  if (validityMatch != null) validityMin = int.tryParse(validityMatch.group(1) ?? '');
  final entities = <String, dynamic>{
    'otp_code': code,
    if (validityMin != null) 'validity_minutes': validityMin,
    if (serviceMatch != null && serviceMatch.group(1) != null) 'service_name': serviceMatch.group(1)!.trim(),
  };
  return SmsAnalysisResult(
    category: SmsIntentCategory.otp,
    riskScore: 5,
    phishingLikelihood: 0.1,
    reasoning: '4–8 digit code with verification/OTP context; time-bound.',
    entities: entities,
  );
}

SmsAnalysisResult? _checkBankTransaction(
  String lower,
  String body, [
  String? senderAddress,
  SmsRegionContext? regionContext,
]) {
  final region = regionContext ?? SmsRegionContext.none;
  final amountPatterns = [
    RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{2})?)\s*(?:rs\.?|inr|₹)', caseSensitive: false),
    RegExp(r'(?:debited|credited|deducted|of)\s+(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false),
    RegExp(r'([\d,]+(?:\.\d{2})?)\s+(?:has\s+been\s+)?(?:debited|credited|deducted)', caseSensitive: false),
  ];
  String? amountStr;
  for (final p in amountPatterns) {
    final m = p.firstMatch(body);
    if (m != null) {
      amountStr = m.group(1)?.replaceAll(',', '');
      if (amountStr != null && amountStr.isNotEmpty) break;
    }
  }
  if (amountStr == null || amountStr.isEmpty) return null;

  final amount = double.tryParse(amountStr);

  final transactionKeywords = RegExp(
    r'\b(?:debited|credited|withdrawn|deposited|payment|purchase|'
    r'deducted|received|refund|transfer(?:red)?|upi|imps|neft|rtgs|'
    r'atm|a/c|account|card\s+ending|balance\s+(?:is|rs|inr)|'
    r'txn|transaction|reference\s+(?:no|number)|avail(?:able)?\s+bal|'
    r'via\s+upi|upi\s+txn|upi\s+ref|google\s+pay|phonepe|paytm\s+(?:wallet|txn)|'
    r'wallet|slice\s+card|simpl\s+payment|lazypay|cred\s+payment|uni\s+card|cred|'
    r'ac\s+debited|ac\s+credited|sent\s+to|received\s+from|amount\s+of|trf\b|trfs|'
    r'withdrawal|deposit|sent\s+successfully|received\s+successfully|inr\s+has\s+been)\b',
    caseSensitive: false,
  );
  final hasTransactionalPrefix = region.isTransactionalSender(senderAddress);
  if (!transactionKeywords.hasMatch(lower) && !hasTransactionalPrefix) return null;

  // Reject spam-like messages that happen to contain amount (lottery, won, claim)
  if (RegExp(r'\b(?:congratulations|you\s+won|claim\s+now|lottery|reward\s+of\s+rs|free\s+money)\b', caseSensitive: false).hasMatch(lower)) {
    return null;
  }

  final promoOnly = RegExp(
    r'\b(?:offer|cashback|discount|sale|limited\s+time|avail\s+now)\b',
    caseSensitive: false,
  );
  final hasDebitCredit = RegExp(
    r'\b(?:debited|credited|withdrawn|deposited|received|payment\s+of|purchase)\b',
    caseSensitive: false,
  ).hasMatch(lower);
  if (promoOnly.hasMatch(lower) && !hasDebitCredit) return null;

  final txType = RegExp(r'\b(?:credited|deposited|received|refund)\b', caseSensitive: false).hasMatch(lower) &&
      !RegExp(r'\b(?:debited|withdrawn|deducted|payment|purchase)\b', caseSensitive: false).hasMatch(lower)
      ? 'CREDIT'
      : 'DEBIT';

  final channelMatch = RegExp(
    r'\b(upi|imps|neft|rtgs|atm|pos|card|a/c|account)\b',
    caseSensitive: false,
  ).firstMatch(lower);
  final refMatch = RegExp(
    r'reference\s*(?:no\.?|number)?\s*[:\-]?\s*([A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(body);
  final balMatch = RegExp(
    r'(?:avail(?:able)?\s*bal|balance)\s*[:\-]?\s*(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)',
    caseSensitive: false,
  ).firstMatch(body);
  final bankMatch = RegExp(
    r'(?:from|by)\s+([A-Za-z\s]+(?:bank|banking))\b',
    caseSensitive: false,
  ).firstMatch(body);

  // Extract account/card last 4 digits
  final last4Patterns = [
    RegExp(r'(?:card|a/c|ac|acct|account)\s*(?:no\.?\s*)?(?:ending\s*(?:in\s*)?|(?:xx|XX|\*{2,4}))(\d{4})\b', caseSensitive: false),
    RegExp(r'(?:xx|XX|\*{2,4})(\d{4})\b'),
    RegExp(r'\b(?:a/c|ac)\s*[:\-]?\s*\w*(\d{4})\b', caseSensitive: false),
  ];
  String? accountLast4;
  for (final p in last4Patterns) {
    final m = p.firstMatch(body);
    if (m != null) {
      accountLast4 = m.group(1);
      break;
    }
  }

  // Detect account sub-type from context
  String? accountType;
  if (RegExp(r'\bcredit\s*card\b', caseSensitive: false).hasMatch(lower)) {
    accountType = 'credit_card';
  } else if (RegExp(r'\bdebit\s*card\b', caseSensitive: false).hasMatch(lower)) {
    accountType = 'debit_card';
  } else if (RegExp(r'\bcard\s+ending\b', caseSensitive: false).hasMatch(lower)) {
    accountType = 'card';
  } else if (RegExp(r'\b(?:savings?|a/c|ac|account)\b', caseSensitive: false).hasMatch(lower)) {
    accountType = 'bank';
  }

  // UPI-specific extraction (Indian context)
  final upiRefMatch = RegExp(
    r'(?:upi\s+ref(?:erence)?\s*(?:no\.?|number)?|ref(?:erence)?\s*(?:no\.?|number)?)\s*[:\-]?\s*(\d{8,12})',
    caseSensitive: false,
  ).firstMatch(body);
  final upiRef = upiRefMatch?.group(1);

  final vpaMatch = RegExp(
    r'(?:to|from|payee|beneficiary)\s+([A-Za-z0-9._+-]+@[A-Za-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(body);
  final payeeVpa = vpaMatch?.group(1)?.trim();

  final payeeNameMatch = RegExp(
    r'(?:to|paid\s+to|transferred\s+to|received\s+from)\s+([A-Za-z][A-Za-z0-9\s]{1,40}?)(?:\s+\.|\s+via|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  String? payeeName = payeeNameMatch?.group(1)?.trim();
  if (payeeName != null && payeeName.length > 50) payeeName = payeeName.substring(0, 50);

  // Merchant/payee for transaction title (Indian: at POS X, paid to X, at X)
  final posMerchantMatch = RegExp(
    r'(?:at|@)\s*POS\s+([A-Za-z0-9\s]{2,50}?)(?:\s+\.|\s+on\s+|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  final toMerchantMatch = RegExp(
    r'(?:paid\s+to|to|at)\s+([A-Z][A-Za-z0-9\s]{0,35}?)(?:\s+\.|\s+via|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  final forMerchantMatch = RegExp(
    r'\bfor\s+([A-Z][A-Za-z0-9\s]{0,35}?)(?:\s+\.|\s+txn|\s+ref|\.|$)',
    caseSensitive: false,
  ).firstMatch(body);
  String? merchant = payeeName;
  merchant ??= posMerchantMatch?.group(1)?.trim();
  merchant ??= toMerchantMatch?.group(1)?.trim();
  merchant ??= forMerchantMatch?.group(1)?.trim();
  if (merchant != null && merchant.length > 50) merchant = merchant.substring(0, 50).trim();

  // Transaction date/time from body (region-specific formats)
  DateTime? transactionDate = region.parseTransactionDate(body);

  double? balanceVal;
  if (balMatch != null) balanceVal = double.tryParse(balMatch.group(1)?.replaceAll(',', '') ?? '');
  final entities = <String, dynamic>{
    if (amount != null) 'amount': amount,
    'currency': 'INR',
    'transaction_type': txType,
    if (channelMatch != null && channelMatch.group(1) != null) 'channel': channelMatch.group(1)!.toUpperCase(),
    if (refMatch != null && refMatch.group(1) != null) 'reference_number': refMatch.group(1),
    if (balanceVal != null) 'balance': balanceVal,
    if (bankMatch != null && bankMatch.group(1) != null) 'bank_name': bankMatch.group(1)!.trim(),
    if (accountLast4 != null) 'account_last_four': accountLast4,
    if (accountType != null) 'account_type': accountType,
    if (upiRef != null) 'upi_ref': upiRef,
    if (payeeVpa != null) 'payee_vpa': payeeVpa,
    if (payeeName != null && payeeName.isNotEmpty) 'payee_name': payeeName,
    if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
    if (transactionDate != null) 'transaction_date': transactionDate.toIso8601String(),
  };
  return SmsAnalysisResult(
    category: SmsIntentCategory.bankTransaction,
    riskScore: 10,
    phishingLikelihood: 0.05,
    reasoning: 'Amount + debit/credit/channel; factual transaction tone.',
    entities: entities,
  );
}

SmsAnalysisResult? _checkBankNonTransactional(String lower, String body) {
  final Map<String, dynamic> entities = {};
  String? subType;
  String reasoning = 'Bank-related but not a transaction.';

  // Bill generated / payment due
  final billDue = RegExp(
    r'\b(?:credit\s+card\s+)?bill\s+(?:of\s+)?(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)\s*(?:is\s+)?generated|'
    r'payment\s+due|due\s+date\s*[:\-]?\s*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{1,2}\s+[A-Za-z]{3})|'
    r'repay\s+by|pay\s+by\s+(\d{1,2}[-/]\d{1,2})',
    caseSensitive: false,
  ).firstMatch(body);
  if (billDue != null) {
    subType = 'bill_due';
    final amt = billDue.group(1);
    if (amt != null) entities['bill_amount'] = double.tryParse(amt.replaceAll(',', ''));
    final d1 = billDue.group(2) ?? billDue.group(3);
    if (d1 != null) entities['due_date'] = d1.trim();
    reasoning = 'Bill due or payment reminder.';
  }

  // Credit limit change
  if (subType == null && RegExp(r'\bcredit\s+limit\s+(?:is\s+now|increased|revised)\b', caseSensitive: false).hasMatch(lower)) {
    final limitMatch = RegExp(r'(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(body);
    if (limitMatch != null) {
      subType = 'credit_limit';
      entities['new_limit'] = double.tryParse(limitMatch.group(1)?.replaceAll(',', '') ?? '');
      reasoning = 'Credit limit update.';
    }
  }

  // Auto-debit / NACH
  if (subType == null && RegExp(r'\b(?:auto\s*[- ]?debit|nach|sip|recurring)\b', caseSensitive: false).hasMatch(lower)) {
    final amtMatch = RegExp(r'(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)\s*(?:will\s+be\s+)?(?:auto\s*[- ]?debited|debited)', caseSensitive: false).firstMatch(body);
    final dateMatch = RegExp(r'(?:on|by)\s+(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{1,2}\s+[A-Za-z]{3})', caseSensitive: false).firstMatch(body);
    if (amtMatch != null || dateMatch != null) {
      subType = 'auto_debit';
      if (amtMatch != null) entities['amount'] = double.tryParse(amtMatch.group(1)?.replaceAll(',', '') ?? '');
      if (dateMatch != null) entities['due_date'] = dateMatch.group(1)?.trim();
      reasoning = 'Auto-debit/NACH/SIP reminder.';
    }
  }

  // FD maturity
  if (subType == null && RegExp(r'\b(?:fd|fixed\s+deposit)\s+(?:of\s+)?(?:rs\.?|inr)?\s*[\d,]+.*matur(?:es|ity)|matur(?:es|ity)\s+on\b', caseSensitive: false).hasMatch(lower)) {
    final amtMatch = RegExp(r'(?:fd|fixed\s+deposit)\s+(?:of\s+)?(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(body);
    final dateMatch = RegExp(r'matur(?:es|ity)\s+on\s+(\d{1,2}[-/]\d{1,2}[-/]\d{2,4}|\d{1,2}\s+[A-Za-z]{3})', caseSensitive: false).firstMatch(body);
    subType = 'fd_maturity';
    if (amtMatch != null) entities['fd_amount'] = double.tryParse(amtMatch.group(1)?.replaceAll(',', '') ?? '');
    if (dateMatch != null) entities['maturity_date'] = dateMatch.group(1)?.trim();
    reasoning = 'FD maturity alert.';
  }

  // Cheque bounce
  if (subType == null && RegExp(r'\bcheque\s+(?:no\.?|number)?\s*\d+.*returned\s+unpaid|returned\s+unpaid\b', caseSensitive: false).hasMatch(lower)) {
    subType = 'cheque_bounce';
    final noMatch = RegExp(r'cheque\s+(?:no\.?|number)?\s*(\d+)', caseSensitive: false).firstMatch(body);
    if (noMatch != null) entities['cheque_number'] = noMatch.group(1);
    reasoning = 'Cheque bounce notification.';
  }

  // Reward points
  if (subType == null && RegExp(r'\b(?:earned|credited)\s+\d+\s+reward\s+points|\breward\s+points\s+(?:earned|credited)\b', caseSensitive: false).hasMatch(lower)) {
    final ptsMatch = RegExp(r'(\d+)\s+reward\s+points', caseSensitive: false).firstMatch(body);
    subType = 'reward_points';
    if (ptsMatch != null) entities['points'] = int.tryParse(ptsMatch.group(1) ?? '');
    reasoning = 'Reward points earned.';
  }

  // Minimum balance alert
  if (subType == null && RegExp(r'\b(?:balance\s+)?(?:is\s+)?below\s+minimum|maintain\s+(?:rs\.?|inr)?\s*[\d,]+|min(?:imum)?\s+balance\b', caseSensitive: false).hasMatch(lower)) {
    final amtMatch = RegExp(r'maintain\s+(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(body);
    subType = 'min_balance_alert';
    if (amtMatch != null) entities['min_balance'] = double.tryParse(amtMatch.group(1)?.replaceAll(',', '') ?? '');
    reasoning = 'Minimum balance alert.';
  }

  // Insurance premium due
  if (subType == null && RegExp(r'\b(?:policy\s+premium|insurance\s+premium).*(?:due|pay)|premium\s+of\s+(?:rs\.?|inr)?\s*[\d,]+\s+due\b', caseSensitive: false).hasMatch(lower)) {
    final amtMatch = RegExp(r'premium\s+(?:of\s+)?(?:rs\.?|inr)?\s*([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(body);
    final dateMatch = RegExp(r'due\s+on\s+(\d{1,2}[-/]\d{1,2}|\d{1,2}\s+[A-Za-z]{3})', caseSensitive: false).firstMatch(body);
    subType = 'insurance_due';
    if (amtMatch != null) entities['premium_amount'] = double.tryParse(amtMatch.group(1)?.replaceAll(',', '') ?? '');
    if (dateMatch != null) entities['due_date'] = dateMatch.group(1)?.trim();
    reasoning = 'Insurance premium due.';
  }

  // Legacy: EMI/KYC/statement (no sub-type)
  if (subType == null) {
    final patterns = RegExp(
      r'\b(?:emi\s+reminder|kyc\s+(?:reminder|pending|update)|statement\s+(?:available|ready)|'
      r'account\s+update|payment\s+due\s+reminder|due\s+date|repay\s+by|'
      r'your\s+statement\s+is\s+ready|complete\s+your\s+kyc)\b',
      caseSensitive: false,
    );
    if (!patterns.hasMatch(lower)) return null;
  }

  if (subType != null) entities['bank_non_txn_subtype'] = subType;
  return SmsAnalysisResult(
    category: SmsIntentCategory.bankNonTransactional,
    riskScore: 15,
    phishingLikelihood: 0.1,
    reasoning: reasoning,
    entities: entities,
  );
}

/// Broker/trading: order executed, funds debited/credited, demat, NSE/BSE.
SmsAnalysisResult? _checkBrokerTransaction(String lower, String body) {
  final brokerKeywords = RegExp(
    r'\b(?:order\s+executed|order\s+placed|trade\s+confirmed|funds\s+(?:credited|debited|transferred)|'
    r'demat|dp\s+debit|dp\s+credit|nse|bse|nifty|bse\s+eq|nse\s+eq|'
    r'buy\s+order|sell\s+order|intraday|delivery\s+order|sip\s+in\s+equity|'
    r'zerodha|upstox|groww|angel\s+one|icici\s+direct|hdfc\s+securities|'
    r'sharekhan|kotak\s+securities|motilal\s+oswal|edelweiss|broker|'
    r'mutual\s+fund|sip\s+invest|redemption|nav\s+update|folio\s+no|'
    r'amfi|sebi|cams|karvy|mf\s+utility|units\s+allotted|dividend\s+declared)\b',
    caseSensitive: false,
  );
  if (!brokerKeywords.hasMatch(lower)) return null;

  final amountPattern = RegExp(
    r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)|([\d,]+(?:\.\d{2})?)\s*(?:rs\.?|inr|₹)',
    caseSensitive: false,
  );
  final amountMatch = amountPattern.firstMatch(body);
  if (amountMatch == null) return null;

  final amountStr = (amountMatch.group(1) ?? amountMatch.group(2)) ?? '';
  final amount = double.tryParse(amountStr.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  final isCredit = RegExp(r'\b(?:credited|received|refund|sell\s+order\s+executed)\b', caseSensitive: false).hasMatch(lower) &&
      !RegExp(r'\b(?:debited|debit|buy\s+order)\b', caseSensitive: false).hasMatch(lower);
  final txType = isCredit ? 'CREDIT' : 'DEBIT';

  final orderIdMatch = RegExp(r'order\s*(?:id|no\.?|#)?\s*[:\-]?\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(body);
  final scriptMatch = RegExp(r'\b([A-Z]{2,10})\s+(?:at|@|order)', caseSensitive: false).firstMatch(body);

  final entities = <String, dynamic>{
    'amount': amount,
    'currency': 'INR',
    'transaction_type': txType,
    if (orderIdMatch != null && orderIdMatch.group(1) != null) 'order_id': orderIdMatch.group(1),
    if (scriptMatch != null && scriptMatch.group(1) != null) 'script': scriptMatch.group(1),
  };
  return SmsAnalysisResult(
    category: SmsIntentCategory.brokerTransaction,
    riskScore: 12,
    phishingLikelihood: 0.05,
    reasoning: 'Broker/trading message with amount (order, funds, demat).',
    entities: entities,
  );
}

/// Broker non-transactional: IPO, corporate action, alerts.
SmsAnalysisResult? _checkBrokerNonTransactional(String lower, String body) {
  final patterns = RegExp(
    r'\b(?:ipo\s+(?:allotted|opening|closing|subscription)|corporate\s+action|dividend|'
    r'bonus\s+share|split|rights\s+issue|delisting|insider\s+trading|'
    r'margin\s+call|pledge|demat\s+statement|contract\s+note|'
    r'zerodha|upstox|groww|angel\s+one|nse|bse|'
    r'sebi|amfi|mutual\s+fund|sip|redemption|nav|folio|cams|karvy)\b',
    caseSensitive: false,
  );
  if (!patterns.hasMatch(lower)) return null;
  if (_checkBrokerTransaction(lower, body) != null) return null;
  return SmsAnalysisResult(
    category: SmsIntentCategory.brokerNonTransactional,
    riskScore: 12,
    phishingLikelihood: 0.05,
    reasoning: 'Broker/trading alert (IPO, corporate action, statement).',
    entities: {},
  );
}

/// SEBI, RBI and other regulatory messages.
SmsAnalysisResult? _checkRegulatory(String lower, String body) {
  final sebiRbi = RegExp(
    r'\b(?:sebi|rbi|reserve\s+bank|securities\s+and\s+exchange\s+board|'
    r'regulatory|circular|master\s+circular|notification\s+no\.?|'
    r'market\s+regulator|banking\s+regulator|depository\s+participant|'
    r'nsdl|cdsl|amfi)\b',
    caseSensitive: false,
  );
  if (!sebiRbi.hasMatch(lower)) return null;

  String? source;
  if (RegExp(r'\bsebi\b', caseSensitive: false).hasMatch(lower)) source = 'SEBI';
  if (RegExp(r'\b(?:rbi|reserve\s+bank)\b', caseSensitive: false).hasMatch(lower)) {
    source = source != null ? 'SEBI_RBI' : 'RBI';
  }

  final entities = <String, dynamic>{
    if (source != null) 'regulatory_source': source,
  };
  return SmsAnalysisResult(
    category: SmsIntentCategory.regulatory,
    riskScore: 5,
    phishingLikelihood: 0.02,
    reasoning: 'Regulatory message (SEBI/RBI/circular).',
    entities: entities,
  );
}

SmsAnalysisResult? _checkPromotional(String lower, String body) {
  final promo = RegExp(
    r'\b(?:offer|offers|discount|sale|sales|cashback|limited\s+time|'
    r'buy\s+now|shop\s+now|avail\s+now|click\s+here|unsubscribe|'
    r'%\s*off|flat\s+\d+%|up\s+to\s+\d+%|best\s+price|deal|'
    r'pre[- ]?approved|avail\s+(?:this|offer)|limited\s+period|'
    r'special\s+offer|exclusive\s+offer|flash\s+sale|clearance)\b',
    caseSensitive: false,
  );
  if (!promo.hasMatch(lower)) return null;
  return SmsAnalysisResult(
    category: SmsIntentCategory.promotional,
    riskScore: 25,
    phishingLikelihood: 0.15,
    reasoning: 'Marketing language: discount/offer/cashback/buy now.',
    entities: {},
  );
}

SmsAnalysisResult? _checkPhishing(String lower, String body) {
  final urgencyFear = RegExp(
    r'\b(?:urgent|immediately|suspend|blocked|verify\s+your\s+account|'
    r'update\s+your\s+(?:bank|card|details)|share\s+(?:otp|password|pin)|'
    r'dear\s+customer\s+your\s+account\s+has\s+been|act\s+now\s+or|'
    r'aapka\s+account|aapke\s+card|verify\s+karein|reactivate|link\s+par\s+click)\b',
    caseSensitive: false,
  );
  final suspiciousLink = RegExp(
    r'https?://(?:bit\.ly|tinyurl|t\.co|goo\.gl|[\w-]+\.(?:tk|ml|ga|cf)|[\w-]+\.(?:xyz|top|club))\S*',
    caseSensitive: false,
  );
  final askSensitive = RegExp(
    r'\b(?:share|send|enter|provide|do\s+not\s+share)\s+(?:your\s+)?(?:otp|password|pin|cvv|card\s+number)\b',
    caseSensitive: false,
  );

  final linkMatch = suspiciousLink.firstMatch(body);
  final impersonation = RegExp(
    r'(?:pretending\s+to\s+be|claim(?:ing)?\s+to\s+be)\s+([^.]+)',
    caseSensitive: false,
  ).firstMatch(body);

  if (!urgencyFear.hasMatch(lower) && linkMatch == null && !askSensitive.hasMatch(lower)) {
    return null;
  }

  double phishing = 0.5;
  if (linkMatch != null) phishing += 0.25;
  if (askSensitive.hasMatch(lower)) phishing += 0.2;
  if (urgencyFear.hasMatch(lower)) phishing += 0.1;

  final entities = <String, dynamic>{
    if (linkMatch != null) 'suspicious_link': linkMatch.group(0),
    if (impersonation != null) 'impersonated_entity': impersonation.group(1)?.trim(),
  };
  return SmsAnalysisResult(
    category: SmsIntentCategory.phishing,
    riskScore: (phishing * 100).round().clamp(61, 95),
    phishingLikelihood: phishing.clamp(0.0, 1.0),
    reasoning: 'Urgency/fear or suspicious link or request for sensitive data.',
    entities: entities,
  );
}

SmsAnalysisResult? _checkSpam(String lower, String body) {
  final spam = RegExp(
    r'\b(?:congratulations\s+you\s+won|claim\s+now|free\s+money|'
    r'reward\s+of\s+rs|lottery|crypto\s+(?:investment|giveaway)|'
    r'you\s+have\s+won\s+rs|rs\.?\s*\d+\s*(?:lakh|crore)\s+won|'
    r'kamao|earn\s+money|investment\s+opportunity|double\s+your\s+money|'
    r'guaranteed\s+returns|winner|click\s+to\s+claim|you\s+are\s+a\s+winner|'
    r'claim\s+your\s+reward|free\s+reward|refer\s+and\s+earn\s+rs)\b',
    caseSensitive: false,
  );
  if (!spam.hasMatch(lower)) return null;
  return SmsAnalysisResult(
    category: SmsIntentCategory.spam,
    riskScore: 70,
    phishingLikelihood: 0.4,
    reasoning: 'Lottery/crypto/unrealistic reward; spam.',
    entities: {},
  );
}

SmsAnalysisResult? _checkServiceNotification(String lower, String body) {
  final service = RegExp(
    r'\b(?:delivery|delivered|out\s+for\s+delivery|subscription\s+renewal|'
    r'appointment\s+reminder|booking\s+confirmed|order\s+shipped|'
    r'track\s+your\s+order|reschedule|order\s+placed|order\s+dispatched|'
    r'your\s+order\s+has|shipment|courier\s+is|delivery\s+partner|'
    r'otp\s+for\s+delivery|delivery\s+otp|slot\s+booked|vaccine\s+reminder)\b',
    caseSensitive: false,
  );
  if (!service.hasMatch(lower)) return null;
  return SmsAnalysisResult(
    category: SmsIntentCategory.serviceNotification,
    riskScore: 15,
    phishingLikelihood: 0.05,
    reasoning: 'Delivery/subscription/appointment/booking notification.',
    entities: {},
  );
}

SmsAnalysisResult? _checkPersonal(String lower, String body) {
  if (body.length > 200) return null;
  final informal = RegExp(
    r'\b(?:hey|hi|hello|thanks|thank you|ok|okay|see you|call me|message me)\b',
    caseSensitive: false,
  );
  final noInstitutional = !RegExp(
    r'\b(?:bank|otp|transaction|debited|credited|offer|click\s+here)\b',
    caseSensitive: false,
  ).hasMatch(lower);
  if (informal.hasMatch(lower) && noInstitutional) {
    return SmsAnalysisResult(
      category: SmsIntentCategory.personal,
      riskScore: 5,
      phishingLikelihood: 0,
      reasoning: 'Informal tone; no institutional structure.',
      entities: {},
    );
  }
  return null;
}
