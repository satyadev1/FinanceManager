import 'package:flutter/material.dart';
import 'package:indian_sms_filter/indian_sms_filter.dart';

import '../config/app_config.dart';
import '../engine/sms_classifier.dart';
import '../models/account.dart';
import '../models/sms_message.dart';
import '../models/transaction.dart';
import '../services/drive_sync_service.dart';
import '../services/sms_import_result.dart';
import '../widgets/bank_logo_widget.dart';
import '../widgets/empty_state.dart';

/// Transaction filter for the Transactions tab: by account type, FASTag, benefits, or broker.
enum _TxnFilter {
  all,
  bank,
  creditCard,
  debitCard,
  fastag,
  benefits,
  broker,
  others,
}

class SmsImportReviewScreen extends StatefulWidget {
  final SmsImportResult result;

  const SmsImportReviewScreen({super.key, required this.result});

  @override
  State<SmsImportReviewScreen> createState() => _SmsImportReviewScreenState();
}

class _SmsImportReviewScreenState extends State<SmsImportReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<DetectedAccount> _accounts;
  late List<Transaction> _transactions;
  late List<SmsMessageModel> _messages;
  final _selectedTxns = <String, bool>{};
  bool _saving = false;
  _TxnFilter _txnFilter = _TxnFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _accounts = List.from(widget.result.detectedAccounts);
    _transactions = List.from(widget.result.transactions);
    _messages = widget.result.messages;
    for (final t in _transactions) {
      _selectedTxns[t.id ?? ''] = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _selectedAccountCount => _accounts.where((a) => a.selected).length;
  int get _selectedTxnCount => _selectedTxns.values.where((v) => v).length;

  /// Account sub-type for a transaction (from linked detected account). Null = no account (Others).
  String? _accountSubTypeForTxn(Transaction t) {
    if (t.accountId == null) return null;
    for (final a in _accounts) {
      if (a.id == t.accountId) return a.subType ?? (a.type == 'card' ? 'card' : 'bank');
    }
    return null;
  }

  bool _txnMatchesFilter(Transaction t) {
    switch (_txnFilter) {
      case _TxnFilter.all:
        return true;
      case _TxnFilter.bank:
        return _accountSubTypeForTxn(t) == 'bank';
      case _TxnFilter.creditCard:
        return _accountSubTypeForTxn(t) == 'credit_card';
      case _TxnFilter.debitCard:
        return _accountSubTypeForTxn(t) == 'debit_card';
      case _TxnFilter.fastag:
        return t.category == 'fastag';
      case _TxnFilter.benefits:
        return t.category == 'benefits';
      case _TxnFilter.broker:
        return t.category == 'broker';
      case _TxnFilter.others:
        return t.accountId == null;
    }
  }

  List<Transaction> get _filteredTransactions =>
      _transactions.where(_txnMatchesFilter).toList();

  /// Which filters have at least one transaction (so we only show relevant chips).
  Set<_TxnFilter> get _availableTxnFilters {
    final set = <_TxnFilter>{_TxnFilter.all};
    for (final t in _transactions) {
      final st = _accountSubTypeForTxn(t);
      if (st == 'bank') set.add(_TxnFilter.bank);
      if (st == 'credit_card') set.add(_TxnFilter.creditCard);
      if (st == 'debit_card') set.add(_TxnFilter.debitCard);
      if (t.accountId == null) set.add(_TxnFilter.others);
      if (t.category == 'fastag') set.add(_TxnFilter.fastag);
      if (t.category == 'benefits') set.add(_TxnFilter.benefits);
      if (t.category == 'broker') set.add(_TxnFilter.broker);
    }
    return set;
  }

  void _setAllFilteredTxnsSelected(bool selected) {
    final ids = _filteredTransactions.map((t) => t.id).whereType<String>().toSet();
    for (final id in ids) {
      _selectedTxns[id] = selected;
    }
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final drive = DriveSyncService.instance;

    final existingLast4s = <String>{};
    for (final a in drive.accounts) {
      if (a.lastFour != null) existingLast4s.add(a.lastFour!);
    }

    final accountIdMap = <String, String>{};

    for (final da in _accounts) {
      if (!da.selected) continue;
      if (da.lastFour != null && existingLast4s.contains(da.lastFour)) {
        final existing = drive.accounts.firstWhere(
          (a) => a.lastFour == da.lastFour,
        );
        accountIdMap[da.id] = existing.id ?? da.id;
        // Update balance if we detected one
        if (da.balance != null) {
          final idx = drive.accounts.indexOf(existing);
          drive.updateAccount(idx, Account(
            id: existing.id,
            name: existing.name,
            type: existing.type,
            balance: da.balance!,
            currency: existing.currency,
            bankName: da.bankName ?? existing.bankName,
            lastFour: existing.lastFour,
            scheme: existing.scheme,
            limitAmount: existing.limitAmount,
            limitPeriod: existing.limitPeriod,
            createdAt: existing.createdAt,
          ));
        }
        continue;
      }

      final account = Account(
        id: da.id,
        name: da.name,
        type: da.type,
        balance: da.balance ?? 0,
        bankName: da.bankName,
        lastFour: da.lastFour,
        scheme: da.subType == 'credit_card' ? 'credit_card' : da.subType == 'debit_card' ? 'debit_card' : null,
        createdAt: DateTime.now(),
      );
      drive.addAccount(account);
      accountIdMap[da.id] = da.id;
    }

    final existingTxnKeys = <String>{};
    for (final t in drive.transactions) {
      existingTxnKeys.add('${t.date.millisecondsSinceEpoch}_${t.amount}_${t.type}');
    }

    int addedCount = 0;
    for (final t in _transactions) {
      if (!(_selectedTxns[t.id ?? ''] ?? false)) continue;
      final key = '${t.date.millisecondsSinceEpoch}_${t.amount}_${t.type}';
      if (existingTxnKeys.contains(key)) continue;

      final mappedAccountId = t.accountId != null ? accountIdMap[t.accountId!] : null;
      drive.addTransaction(Transaction(
        id: t.id,
        title: t.title,
        amount: t.amount,
        type: t.type,
        date: t.date,
        source: 'sms',
        accountId: mappedAccountId ?? t.accountId,
        category: t.category,
        createdAt: t.createdAt,
      ));
      addedCount++;
    }

    await drive.saveAccounts();
    await drive.saveTransactions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $_selectedAccountCount account(s) and $addedCount transaction(s).')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Import Review'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Accounts (${_accounts.length})'),
            Tab(text: 'Transactions (${_transactions.length})'),
            Tab(text: 'Messages (${_messages.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountsTab(theme),
          _buildTransactionsTab(theme),
          _buildMessagesTab(theme),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_saving
                ? 'Saving...'
                : 'Save $_selectedAccountCount account(s) & $_selectedTxnCount transaction(s)'),
          ),
        ),
      ),
    );
  }

  void _mergeDetectedAccounts(String keepId, List<String> mergeAwayIds) {
    if (mergeAwayIds.isEmpty) return;
    final toRemove = mergeAwayIds.toSet();
    _transactions = _transactions.map((t) {
      if (t.accountId != null && toRemove.contains(t.accountId!)) {
        return Transaction(
          id: t.id,
          title: t.title,
          amount: t.amount,
          type: t.type,
          date: t.date,
          source: t.source,
          accountId: keepId,
          category: t.category,
          createdAt: t.createdAt,
        );
      }
      return t;
    }).toList();
    _accounts.removeWhere((a) => a.id != null && toRemove.contains(a.id!));
    for (final a in _accounts) {
      if (a.id == keepId) {
        a.transactionCount = _transactions.where((t) => t.accountId == keepId).length;
        break;
      }
    }
    setState(() {});
  }

  void _openMergeDuringImport() {
    if (_accounts.length < 2) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => _ImportMergeAccountsScreen(
          accounts: List.from(_accounts),
          transactions: _transactions,
          onMerge: (keepId, mergeAwayIds) {
            _mergeDetectedAccounts(keepId, mergeAwayIds);
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Merged ${mergeAwayIds.length} account(s).')),
            );
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildAccountsTab(ThemeData theme) {
    if (_accounts.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Nothing is available',
        subtitle: 'No accounts detected from SMS.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_accounts.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextButton.icon(
              onPressed: _openMergeDuringImport,
              icon: const Icon(Icons.merge_type, size: 20),
              label: const Text('Merge accounts'),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _accounts.length,
      itemBuilder: (context, i) {
        final da = _accounts[i];
        final relatedMessages = _messagesForAccount(da);
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                value: da.selected,
                onChanged: (v) => setState(() => da.selected = v ?? true),
                secondary: BankLogoWidget(
                  brandInfo: (da.bankName != null || da.name.isNotEmpty)
                      ? IndianSmsPlugin.instance.getBrandInfoByName(
                          da.bankName ?? da.name,
                          logoApiToken: AppConfig.smsLogoApiToken,
                        )
                      : null,
                  size: 40,
                ),
                title: Text(da.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (da.bankName != null) Text(da.bankName!),
                    if (da.lastFour != null) Text('****${da.lastFour}'),
                    if (da.balance != null) Text('Balance: ₹${da.balance!.toStringAsFixed(2)}'),
                    Text('${da.transactionCount} transaction(s)',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
                isThreeLine: true,
              ),
              // Inline preview of related messages so user can see which SMS belong to this account
              if (relatedMessages.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Related messages (tap to see full SMS and decide)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...relatedMessages.take(3).map((m) {
                  final preview = m.body.length > 80 ? '${m.body.substring(0, 80)}…' : m.body;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: InkWell(
                      onTap: () => _showAccountMessages(da),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BankLogoWidget(
                              brandInfo: m.address.isNotEmpty
                                  ? IndianSmsPlugin.instance.getBrandInfo(
                                      m.address,
                                      logoApiToken: AppConfig.smsLogoApiToken,
                                    )
                                  : null,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (m.bankName ?? (m.address.isNotEmpty ? m.address : 'Unknown')),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    preview,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (relatedMessages.length > 3)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextButton.icon(
                      onPressed: () => _showAccountMessages(da),
                      icon: const Icon(Icons.inbox, size: 18),
                      label: Text('View all ${relatedMessages.length} messages'),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAccountMessages(da),
                      icon: const Icon(Icons.sms, size: 16),
                      label: Text(relatedMessages.isEmpty
                          ? 'No related SMS'
                          : 'SMS (${relatedMessages.length})'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _editAccount(i),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab(ThemeData theme) {
    if (_transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nothing is available',
        subtitle: 'No transactions found from SMS.',
      );
    }
    final available = _availableTxnFilters;
    final filtered = _filteredTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._TxnFilter.values.where(available.contains).map((f) {
                final label = _txnFilterLabel(f);
                final count = f == _TxnFilter.all
                    ? _transactions.length
                    : _transactions.where((t) {
                        switch (f) {
                          case _TxnFilter.all:
                            return true;
                          case _TxnFilter.bank:
                            return _accountSubTypeForTxn(t) == 'bank';
                          case _TxnFilter.creditCard:
                            return _accountSubTypeForTxn(t) == 'credit_card';
                          case _TxnFilter.debitCard:
                            return _accountSubTypeForTxn(t) == 'debit_card';
                          case _TxnFilter.fastag:
                            return t.category == 'fastag';
                          case _TxnFilter.benefits:
                            return t.category == 'benefits';
                          case _TxnFilter.broker:
                            return t.category == 'broker';
                          case _TxnFilter.others:
                            return t.accountId == null;
                        }
                      }).length;
                return FilterChip(
                  label: Text('$label ($count)'),
                  selected: _txnFilter == f,
                  onSelected: (v) => setState(() => _txnFilter = f),
                  showCheckmark: true,
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} shown',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _setAllFilteredTxnsSelected(true),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add all'),
              ),
              TextButton.icon(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _setAllFilteredTxnsSelected(false),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Remove all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No transactions in "${_txnFilterLabel(_txnFilter)}".',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final selected = _selectedTxns[t.id ?? ''] ?? false;
                    final isCredit = t.type == 'credit';
                    final accountName = _accountNameForId(t.accountId);
                    final isFastag = t.category == 'fastag';
                    return Card(
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: (v) =>
                            setState(() => _selectedTxns[t.id ?? ''] = v ?? false),
                        secondary: isFastag
                            ? Icon(Icons.toll, color: theme.colorScheme.primary)
                            : null,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${isCredit ? '+' : '-'} ₹${t.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isCredit
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                            if (isFastag)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Chip(
                                  label: const Text('FASTag', style: TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              '${t.date.day}/${t.date.month}/${t.date.year}'
                              '${accountName != null ? ' · $accountName' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _txnFilterLabel(_TxnFilter f) {
    switch (f) {
      case _TxnFilter.all:
        return 'All';
      case _TxnFilter.bank:
        return 'Bank';
      case _TxnFilter.creditCard:
        return 'Credit Card';
      case _TxnFilter.debitCard:
        return 'Debit Card';
      case _TxnFilter.fastag:
        return 'FASTag';
      case _TxnFilter.benefits:
        return 'Benefits';
      case _TxnFilter.broker:
        return 'Broker';
      case _TxnFilter.others:
        return 'Others';
    }
  }

  Widget _buildMessagesTab(ThemeData theme) {
    if (_messages.isEmpty) {
      return EmptyState(
        icon: Icons.sms_outlined,
        title: 'Nothing is available',
        subtitle: 'No messages to show.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _buildClassificationSummary(theme),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              return Card(
                child: ListTile(
                  leading: BankLogoWidget(
                    brandInfo: m.address.isNotEmpty
                        ? IndianSmsPlugin.instance.getBrandInfo(
                            m.address,
                            logoApiToken: AppConfig.smsLogoApiToken,
                          )
                        : null,
                    size: 40,
                  ),
                  title: Text(
                    m.bankName ?? (m.address.isNotEmpty ? m.address : 'Unknown'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    m.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${m.date.day}/${m.date.month}',
                    style: theme.textTheme.bodySmall,
                  ),
                  isThreeLine: true,
                  onTap: () => _showMessageDetail(m),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassificationSummary(ThemeData theme) {
    final counts = widget.result.classificationCounts;
    if (counts == null || counts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: counts.entries.map((e) {
        return Chip(
          avatar: _categoryIcon(e.key, theme),
          label: Text('${e.key.displayLabel}: ${e.value}', style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _categoryIcon(SmsCategory cat, ThemeData theme) {
    switch (cat) {
      case SmsCategory.bankTransaction:
        return Icon(Icons.account_balance, size: 20, color: Colors.green.shade700);
      case SmsCategory.otp:
        return Icon(Icons.lock, size: 20, color: Colors.blue.shade700);
      case SmsCategory.promotional:
        return Icon(Icons.local_offer, size: 20, color: Colors.orange.shade700);
      case SmsCategory.spam:
        return Icon(Icons.report, size: 20, color: Colors.red.shade700);
      case SmsCategory.broker:
        return Icon(Icons.show_chart, size: 20, color: Colors.indigo.shade700);
      case SmsCategory.regulatory:
        return Icon(Icons.gavel, size: 20, color: Colors.teal.shade700);
      case SmsCategory.other:
        return Icon(Icons.chat_bubble_outline, size: 20, color: theme.colorScheme.outline);
    }
  }

  String? _accountNameForId(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  /// Returns SMS messages that match the given detected account by last-4 digits and/or bank name.
  /// Includes bank transaction and other bank-related messages (e.g. bank non-transactional) so
  /// the user can see all relevant SMS and decide which account each belongs to.
  List<SmsMessageModel> _messagesForAccount(DetectedAccount da) {
    return _messages.where((m) {
      final last4Match = da.lastFour != null &&
          m.accountLast4 != null &&
          da.lastFour == m.accountLast4;
      final bankMatch = da.bankName != null &&
          m.bankName != null &&
          da.bankName!.toLowerCase() == m.bankName!.toLowerCase();
      final hasMatch = (da.lastFour != null && m.accountLast4 != null && last4Match) ||
          (da.bankName != null && m.bankName != null && bankMatch);
      if (!hasMatch) return false;
      // Include bank transaction and any message with bank/account info (e.g. bank non-txn)
      if (m.category == SmsCategory.bankTransaction) return true;
      if (m.category == SmsCategory.other &&
          (m.bankName != null || m.accountLast4 != null)) return true;
      return false;
    }).toList();
  }

  void _showMessageDetail(SmsMessageModel m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    BankLogoWidget(
                      brandInfo: m.address.isNotEmpty
                          ? IndianSmsPlugin.instance.getBrandInfo(
                              m.address,
                              logoApiToken: AppConfig.smsLogoApiToken,
                            )
                          : (m.bankName != null
                              ? IndianSmsPlugin.instance.getBrandInfoByName(
                                  m.bankName!,
                                  logoApiToken: AppConfig.smsLogoApiToken,
                                )
                              : null),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    _categoryIcon(m.category, theme),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.bankName ?? (m.address.isNotEmpty ? m.address : 'Unknown Sender'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Chip(
                      label: Text(m.category.displayLabel, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${m.date.day}/${m.date.month}/${m.date.year} at ${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    m.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
                if (m.bankName != null || m.accountLast4 != null || m.amount != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Extracted Details', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (m.bankName != null)
                    _detailRow('Bank', m.bankName!, theme),
                  if (m.accountLast4 != null)
                    _detailRow('Account', '****${m.accountLast4}', theme),
                  if (m.accountType != null)
                    _detailRow('Type', _formatAccountType(m.accountType!), theme),
                  if (m.amount != null)
                    _detailRow('Amount', '₹${m.amount!.toStringAsFixed(2)}', theme),
                  if (m.transactionType != null)
                    _detailRow('Transaction', m.transactionType!, theme),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  String _formatAccountType(String type) {
    switch (type) {
      case 'credit_card': return 'Credit Card';
      case 'debit_card': return 'Debit Card';
      case 'card': return 'Card';
      case 'bank': return 'Bank Account';
      default: return type;
    }
  }

  void _showAccountMessages(DetectedAccount da) {
    final related = _messagesForAccount(da);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline.withAlpha(80),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            da.type == 'card' ? Icons.credit_card : Icons.account_balance,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  da.name,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (da.bankName != null)
                                  Text(da.bankName!, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            '${related.length} message(s)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                    ],
                  ),
                ),
                Expanded(
                  child: related.isEmpty
                      ? Center(
                          child: Text(
                            'No related SMS messages found.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: related.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final m = related[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        BankLogoWidget(
                                          brandInfo: m.address.isNotEmpty
                                              ? IndianSmsPlugin.instance.getBrandInfo(
                                                  m.address,
                                                  logoApiToken: AppConfig.smsLogoApiToken,
                                                )
                                              : null,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            m.bankName ?? (m.address.isNotEmpty ? m.address : 'Unknown'),
                                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '${m.date.day}/${m.date.month}/${m.date.year}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: SelectableText(
                                        m.body,
                                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                                      ),
                                    ),
                                    if (m.amount != null || m.transactionType != null) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (m.transactionType != null)
                                            Chip(
                                              label: Text(
                                                m.transactionType!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: m.transactionType == 'CREDIT'
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                ),
                                              ),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                          if (m.amount != null)
                                            Chip(
                                              label: Text(
                                                '₹${m.amount!.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                          if (m.bankName != null)
                                            Chip(
                                              label: Text(m.bankName!, style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                          if (m.accountLast4 != null)
                                            Chip(
                                              label: Text('****${m.accountLast4}', style: const TextStyle(fontSize: 11)),
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editAccount(int index) {
    final da = _accounts[index];
    final nameCtrl = TextEditingController(text: da.name);
    final bankCtrl = TextEditingController(text: da.bankName ?? '');
    final last4Ctrl = TextEditingController(text: da.lastFour ?? '');
    final balCtrl = TextEditingController(text: da.balance?.toStringAsFixed(2) ?? '');
    var isCard = da.type == 'card';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Edit Account', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Card (otherwise Bank)'),
                    value: isCard,
                    onChanged: (v) => setSheetState(() => isCard = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bankCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: last4Ctrl,
                    decoration: const InputDecoration(labelText: 'Last 4 Digits'),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                  ),
                  TextField(
                    controller: balCtrl,
                    decoration: const InputDecoration(labelText: 'Balance'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        da.name = nameCtrl.text.trim().isEmpty ? da.displayName : nameCtrl.text.trim();
                        da.bankName = bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim();
                        da.lastFour = last4Ctrl.text.trim().isEmpty ? null : last4Ctrl.text.trim();
                        da.balance = double.tryParse(balCtrl.text.trim());
                        da.type = isCard ? 'card' : 'bank';
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Merge flow for detected accounts during SMS import (in-memory only).
class _ImportMergeAccountsScreen extends StatefulWidget {
  final List<DetectedAccount> accounts;
  final List<Transaction> transactions;
  final void Function(String keepId, List<String> mergeAwayIds) onMerge;

  const _ImportMergeAccountsScreen({
    required this.accounts,
    required this.transactions,
    required this.onMerge,
  });

  @override
  State<_ImportMergeAccountsScreen> createState() => _ImportMergeAccountsScreenState();
}

class _ImportMergeAccountsScreenState extends State<_ImportMergeAccountsScreen> {
  final _selectedIds = <String>{};
  int _step = 0;

  List<DetectedAccount> get _selectedAccounts =>
      widget.accounts.where((a) => a.id != null && _selectedIds.contains(a.id!)).toList();

  void _continueToKeepStep() {
    if (_selectedAccounts.length >= 2) setState(() => _step = 1);
  }

  void _mergeInto(DetectedAccount keep) {
    final keepId = keep.id!;
    final mergeAway = _selectedAccounts.where((a) => a.id != keepId).map((a) => a.id!).toList();
    if (mergeAway.isEmpty) return;
    widget.onMerge(keepId, mergeAway);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_step == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Merge accounts')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select 2 or more accounts to merge. All transactions will move into the account you choose to keep.'),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: widget.accounts.length,
                itemBuilder: (context, i) {
                  final a = widget.accounts[i];
                  final id = a.id;
                  if (id == null) return const SizedBox.shrink();
                  final isCard = a.type == 'card';
                  final selected = _selectedIds.contains(id);
                  return Card(
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (v) => setState(() {
                        if (v == true) _selectedIds.add(id);
                        else _selectedIds.remove(id);
                      }),
                      secondary: Icon(isCard ? Icons.credit_card : Icons.account_balance, color: theme.colorScheme.primary),
                      title: Text(a.name),
                      subtitle: a.bankName != null || a.lastFour != null
                          ? Text([if (a.bankName != null) a.bankName!, if (a.lastFour != null) '****${a.lastFour}'].join(' · '))
                          : null,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _selectedAccounts.length >= 2 ? _continueToKeepStep : null,
                child: Text('Continue (${_selectedAccounts.length} selected)'),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keep which account?'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step = 0)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('All transactions from the other selected account(s) will be moved into the one you choose below.'),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _selectedAccounts.length,
              itemBuilder: (context, i) {
                final a = _selectedAccounts[i];
                final isCard = a.type == 'card';
                final txnCount = widget.transactions.where((t) => t.accountId == a.id).length;
                return Card(
                  child: ListTile(
                    leading: Icon(isCard ? Icons.credit_card : Icons.account_balance, color: theme.colorScheme.primary),
                    title: Text(a.name),
                    subtitle: Text([if (a.bankName != null) a.bankName!, if (a.lastFour != null) '****${a.lastFour}', '$txnCount txn(s)'].join(' · ')),
                    trailing: FilledButton(onPressed: () => _mergeInto(a), child: const Text('Merge into this')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
