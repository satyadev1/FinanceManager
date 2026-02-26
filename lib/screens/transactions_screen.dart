import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../theme/finance_colors.dart';
import '../services/drive_sync_service.dart';
import '../utils/app_animations.dart';
import '../widgets/empty_state.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  final DriveSyncService _drive = DriveSyncService.instance;
  bool _loading = true;
  String? _error;
  late AnimationController _listAnimController;
  bool _listAnimStarted = false;

  @override
  void initState() {
    super.initState();
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _load();
  }

  @override
  void dispose() {
    _listAnimController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _drive.loadAll();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveTransactions() async {
    try {
      await _drive.saveTransactions();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  String _accountName(String? id) {
    if (id == null) return '—';
    final found = _drive.accounts.where((a) => a.id == id);
    return found.isEmpty ? id : found.first.name;
  }

  void _openAdd() {
    Navigator.of(context).push(
      appPageRoute(
        page: _TransactionFormScreen(
          accounts: _drive.accounts,
          onSave: (t) async {
            _drive.addTransaction(t);
            await _saveTransactions();
          },
        ),
      ),
    ).then((_) => setState(() {}));
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
    final list = _drive.transactions;
    if (!_listAnimStarted && list.isNotEmpty) {
      _listAnimStarted = true;
      _listAnimController.forward();
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _listAnimController.reset();
          _listAnimStarted = false;
          await _load();
          if (mounted && _drive.transactions.isNotEmpty) {
            _listAnimStarted = true;
            _listAnimController.forward();
          }
        },
        child: list.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing is available',
                    subtitle: 'Add a transaction to get started.',
                    action: FilledButton.icon(
                      onPressed: _openAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add transaction'),
                    ),
                  ),
                ),
              )
            : ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final t = list[i];
            final isCredit = t.type == 'credit';
            final finance = Theme.of(context).extension<FinanceColors>();
            final amountColor = isCredit
                ? (finance?.successGain ?? Colors.green)
                : (finance?.dangerLoss ?? Theme.of(context).colorScheme.error);
            return StaggeredListItem(
              index: i,
              itemCount: list.length,
              controller: _listAnimController,
              child: Card(
                child: ListTile(
                  title: Text(t.title),
                  subtitle: Text('${t.date.toString().substring(0, 10)} · ${_accountName(t.accountId)}'),
                  trailing: Text(
                    '${isCredit ? "+" : "-"} ${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_transactions',
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TransactionFormScreen extends StatefulWidget {
  final List<Account> accounts;
  final void Function(Transaction) onSave;

  const _TransactionFormScreen({required this.accounts, required this.onSave});

  @override
  State<_TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<_TransactionFormScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _type = 'debit';
  DateTime _date = DateTime.now();
  String? _accountId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter title')));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final t = Transaction(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      type: _type,
      date: _date,
      accountId: _accountId,
      createdAt: DateTime.now(),
    );
    widget.onSave(t);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'debit', label: Text('Debit'), icon: Icon(Icons.arrow_downward)),
              ButtonSegment(value: 'credit', label: Text('Credit'), icon: Icon(Icons.arrow_upward)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('Date: ${_date.toString().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (widget.accounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— None —')),
                ...widget.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }
}
