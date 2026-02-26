import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/drive_sync_service.dart';
import '../utils/report_aggregator.dart';
import '../widgets/empty_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DriveSyncService _drive = DriveSyncService.instance;
  bool _loading = true;
  String? _error;
  String _period = 'this_month';
  String _typeFilter = 'both';
  ReportTotals? _totals;
  SpendAnalysis? _spendAnalysis;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _drive.loadAll();
      _compute();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _compute() {
    final (start, end) = periodRange(_period);
    final filter = ReportFilter(
      start: start,
      end: end,
      typeFilter: _typeFilter,
    );
    _totals = aggregateReport(
      transactions: _drive.transactions,
      accounts: _drive.accounts,
      filter: filter,
    );
    _spendAnalysis = aggregateSpendAnalysis(
      transactions: _drive.transactions,
      accounts: _drive.accounts,
      filter: filter,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_drive.transactions.isEmpty) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.bar_chart,
          title: 'Nothing is available',
          subtitle: 'Add transactions to see reports and spending analysis.',
        ),
      );
    }
    final t = _totals!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Period', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('This week', 'this_week'),
                  _chip('This month', 'this_month'),
                  _chip('Last month', 'last_month'),
                  _chip('Last 3 months', 'last_3_months'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'both', label: Text('Both')),
                ButtonSegment(value: 'debit', label: Text('Debit')),
                ButtonSegment(value: 'credit', label: Text('Credit')),
              ],
              selected: {_typeFilter},
              onSelectionChanged: (s) {
                setState(() {
                  _typeFilter = s.first;
                  _compute();
                });
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total debits', style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      t.totalDebits.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text('Total credits', style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      t.totalCredits.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('By account', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...t.byAccount.map((r) => Card(
                  child: ListTile(
                    title: Text(r.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.amount.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                    subtitle: r.percentOfTotal != null ? Text('${r.percentOfTotal!.toStringAsFixed(1)}% of total') : null,
                    onTap: () => _showAccountTransactions(r),
                  ),
                )),
            if (_spendAnalysis != null) ...[
              const SizedBox(height: 24),
              const Text('Spend analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total spend (debits)', style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        _spendAnalysis!.totalSpend.toStringAsFixed(2),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              if (_spendAnalysis!.byCategory.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('By category', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ..._spendAnalysis!.byCategory.map((r) => Card(
                      child: ListTile(
                        title: Text(r.label),
                        trailing: Text(
                          '${r.amount.toStringAsFixed(2)}${r.percentOfTotal != null ? ' (${r.percentOfTotal!.toStringAsFixed(0)}%)' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )),
              ],
              if (_spendAnalysis!.byMonth.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Spend by month', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ..._spendAnalysis!.byMonth.map((r) => Card(
                      child: ListTile(
                        title: Text(r.label),
                        trailing: Text(
                          r.amount.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Transaction> _transactionsForAccount(String? accountId) {
    final (start, end) = periodRange(_period);
    return _drive.transactions.where((t) {
      if (t.accountId != accountId) return false;
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      if (_typeFilter == 'debit' && t.type != 'debit') return false;
      if (_typeFilter == 'credit' && t.type != 'credit') return false;
      return true;
    }).toList();
  }

  void _showAccountTransactions(ReportRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final txns = _transactionsForAccount(row.accountId);
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                              Icon(Icons.account_balance, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  row.label,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                '₹${row.amount.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${txns.length} transaction(s)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const Divider(height: 20),
                        ],
                      ),
                    ),
                    Expanded(
                      child: txns.isEmpty
                          ? Center(
                              child: Text(
                                'No transactions for this account.',
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: txns.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (ctx, i) {
                                final t = txns[i];
                                final isCredit = t.type == 'credit';
                                return Dismissible(
                                  key: ValueKey(t.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.delete, color: Colors.red.shade700),
                                  ),
                                  confirmDismiss: (_) async {
                                    return await showDialog<bool>(
                                      context: ctx,
                                      builder: (d) => AlertDialog(
                                        title: const Text('Remove transaction?'),
                                        content: Text(
                                          '${t.title}\n'
                                          '${isCredit ? "+" : "-"} ₹${t.amount.toStringAsFixed(2)}\n'
                                          '${t.date.day}/${t.date.month}/${t.date.year}',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(d, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(d, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    ) ?? false;
                                  },
                                  onDismissed: (_) async {
                                    await _deleteTransaction(t);
                                    setSheetState(() {});
                                  },
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    child: ListTile(
                                      leading: Icon(
                                        isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                                        color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                                        size: 20,
                                      ),
                                      title: Text(
                                        t.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${t.date.day}/${t.date.month}/${t.date.year}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          if (t.source == 'sms')
                                            Text(
                                              'Source: SMS',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          if (t.category != null)
                                            Text(
                                              t.category!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Text(
                                        '${isCredit ? "+" : "-"} ₹${t.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                      ),
                                      isThreeLine: true,
                                      onTap: () => _showTransactionDetail(t),
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
      },
    ).then((_) {
      setState(() => _compute());
    });
  }

  Future<void> _deleteTransaction(Transaction t) async {
    final idx = _drive.transactions.indexWhere((x) => x.id == t.id);
    if (idx >= 0) {
      _drive.removeTransactionAt(idx);
      await _drive.saveTransactions();
    }
  }

  void _showTransactionDetail(Transaction t) {
    final theme = Theme.of(context);
    final isCredit = t.type == 'credit';
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text(
                t.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _detailRow('Amount', '${isCredit ? "+" : "-"} ₹${t.amount.toStringAsFixed(2)}', theme,
                  valueColor: isCredit ? Colors.green.shade700 : Colors.red.shade700),
              _detailRow('Type', isCredit ? 'Credit' : 'Debit', theme),
              _detailRow('Date', '${t.date.day}/${t.date.month}/${t.date.year}', theme),
              _detailRow('Source', t.source, theme),
              if (t.category != null)
                _detailRow('Category', t.category!, theme),
              if (t.accountId != null)
                _detailRow('Account', _accountNameForId(t.accountId), theme),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Remove transaction?'),
                        content: Text('This will permanently delete "${t.title}".'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _deleteTransaction(t);
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() => _compute());
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove transaction'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  String _accountNameForId(String? id) {
    if (id == null) return '—';
    final found = _drive.accounts.where((a) => a.id == id);
    return found.isEmpty ? id : found.first.name;
  }

  Widget _chip(String label, String value) {
    final selected = _period == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _period = value;
            _compute();
          });
        },
      ),
    );
  }
}
