import 'package:flutter/material.dart';
import 'package:indian_sms_filter/indian_sms_filter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/account.dart';
import '../services/drive_sync_service.dart';
import '../utils/app_animations.dart';
import '../widgets/bank_logo_widget.dart';
import '../widgets/empty_state.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _saveAccounts() async {
    try {
      await _drive.saveAccounts();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _openAddAccount() {
    Navigator.of(context).push(
      appPageRoute(
        page: _AccountFormScreen(
          onSave: (a) async {
            _drive.addAccount(a);
            await _saveAccounts();
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openEditAccount(int index) {
    final a = _drive.accounts[index];
    Navigator.of(context).push(
      appPageRoute(
        page: _AccountFormScreen(
          initial: a,
          onSave: (updated) async {
            _drive.updateAccount(index, updated);
            await _saveAccounts();
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
    final list = _drive.accounts;
    if (!_listAnimStarted && list.isNotEmpty) {
      _listAnimStarted = true;
      _listAnimController.forward();
    }
    return Scaffold(
      appBar: list.length >= 2
          ? AppBar(
              title: const Text('Accounts'),
              actions: [
                TextButton.icon(
                  onPressed: _openMergeAccounts,
                  icon: const Icon(Icons.merge_type, size: 20),
                  label: const Text('Merge'),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          _listAnimController.reset();
          _listAnimStarted = false;
          await _load();
          if (mounted && _drive.accounts.isNotEmpty) {
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
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Nothing is available',
                    subtitle: 'Add an account to get started.',
                    action: FilledButton.icon(
                      onPressed: _openAddAccount,
                      icon: const Icon(Icons.add),
                      label: const Text('Add account'),
                    ),
                  ),
                ),
              )
            : ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final a = list[i];
            final isCard = a.type == 'card';
            final subtitle = isCard && a.limitAmount != null
                ? 'Limit: ${a.limitAmount!.toStringAsFixed(0)} (${a.limitPeriod ?? "total"})'
                : null;
            return StaggeredListItem(
              index: i,
              itemCount: list.length,
              controller: _listAnimController,
              child: Card(
                child: ListTile(
                  leading: BankLogoWidget(
                    brandInfo: IndianSmsPlugin.instance.getBrandInfoByName(
                      a.bankName ?? a.name,
                      logoApiToken: AppConfig.smsLogoApiToken,
                    ),
                    size: 40,
                  ),
                  title: Text(a.name),
                  subtitle: subtitle != null
                      ? Text(subtitle)
                      : Row(
                          children: [
                            Text('Balance: ', style: Theme.of(context).textTheme.bodySmall),
                            AnimatedCount(
                              value: a.balance,
                              suffix: ' ${a.currency}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditAccount(i),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_accounts',
        onPressed: _openAddAccount,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openMergeAccounts() {
    final list = _drive.accounts;
    if (list.length < 2) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => _MergeAccountsScreen(
          accounts: List.from(list),
          onMerge: (keepAccountId, mergeAwayAccountIds) async {
            _drive.mergeAccounts(keepAccountId, mergeAwayAccountIds);
            await _drive.saveAccounts();
            await _drive.saveTransactions();
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Merged ${mergeAwayAccountIds.length} account(s).')),
              );
            }
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

/// Screen to merge two or more accounts: select accounts, then choose which to keep.
class _MergeAccountsScreen extends StatefulWidget {
  final List<Account> accounts;
  final void Function(String keepAccountId, List<String> mergeAwayAccountIds) onMerge;

  const _MergeAccountsScreen({required this.accounts, required this.onMerge});

  @override
  State<_MergeAccountsScreen> createState() => _MergeAccountsScreenState();
}

class _MergeAccountsScreenState extends State<_MergeAccountsScreen> {
  final _selectedIds = <String>{};
  int _step = 0; // 0 = select accounts, 1 = choose keep

  List<Account> get _selectedAccounts =>
      widget.accounts.where((a) => a.id != null && _selectedIds.contains(a.id!)).toList();

  void _continueToKeepStep() {
    if (_selectedAccounts.length >= 2) setState(() => _step = 1);
  }

  void _mergeInto(Account keep) {
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select 2 or more accounts to merge. All transactions will move into the account you choose to keep.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: widget.accounts.length,
                itemBuilder: (context, i) {
                  final a = widget.accounts[i];
                  final id = a.id;
                  if (id == null) return const SizedBox.shrink();
                  final selected = _selectedIds.contains(id);
                  return Card(
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) _selectedIds.add(id);
                          else _selectedIds.remove(id);
                        });
                      },
                      secondary: BankLogoWidget(
                        brandInfo: IndianSmsPlugin.instance.getBrandInfoByName(
                          a.bankName ?? a.name,
                          logoApiToken: AppConfig.smsLogoApiToken,
                        ),
                        size: 40,
                      ),
                      title: Text(a.name),
                      subtitle: a.bankName != null || a.lastFour != null
                          ? Text([if (a.bankName != null) a.bankName, if (a.lastFour != null) '****${a.lastFour}'].join(' · '))
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _step = 0),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'All transactions from the other selected account(s) will be moved into the one you choose below.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _selectedAccounts.length,
              itemBuilder: (context, i) {
                final a = _selectedAccounts[i];
                final txnCount = DriveSyncService.instance.transactions.where((t) => t.accountId == a.id).length;
                return Card(
                  child: ListTile(
                    leading: BankLogoWidget(
                      brandInfo: IndianSmsPlugin.instance.getBrandInfoByName(
                        a.bankName ?? a.name,
                        logoApiToken: AppConfig.smsLogoApiToken,
                      ),
                      size: 40,
                    ),
                    title: Text(a.name),
                    subtitle: Text(
                      [if (a.bankName != null) a.bankName, if (a.lastFour != null) '****${a.lastFour}', '$txnCount txn(s)'].join(' · '),
                    ),
                    trailing: FilledButton(
                      onPressed: () => _mergeInto(a),
                      child: const Text('Merge into this'),
                    ),
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

class _AccountFormScreen extends StatefulWidget {
  final Account? initial;
  final void Function(Account) onSave;

  const _AccountFormScreen({this.initial, required this.onSave});

  @override
  State<_AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<_AccountFormScreen> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _lastFourCtrl = TextEditingController();
  final _limitAmountCtrl = TextEditingController();
  bool _isCard = false;
  String _limitPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final a = widget.initial!;
      _nameCtrl.text = a.name;
      _balanceCtrl.text = a.balance.toString();
      _bankNameCtrl.text = a.bankName ?? '';
      _lastFourCtrl.text = a.lastFour ?? '';
      _limitAmountCtrl.text = a.limitAmount?.toString() ?? '';
      _isCard = a.type == 'card';
      _limitPeriod = a.limitPeriod ?? 'monthly';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _bankNameCtrl.dispose();
    _lastFourCtrl.dispose();
    _limitAmountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name')));
      return;
    }
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final limitAmount = double.tryParse(_limitAmountCtrl.text.trim());
    final account = Account(
      id: widget.initial?.id ?? const Uuid().v4(),
      name: name,
      type: _isCard ? 'card' : 'bank',
      balance: balance,
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      lastFour: _lastFourCtrl.text.trim().isEmpty ? null : _lastFourCtrl.text.trim(),
      scheme: _isCard ? 'card' : null,
      limitAmount: limitAmount,
      limitPeriod: limitAmount != null ? _limitPeriod : null,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );
    widget.onSave(account);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add account' : 'Edit account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Card (otherwise Bank)'),
            value: _isCard,
            onChanged: (v) => setState(() => _isCard = v),
          ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          if (!_isCard) ...[
            TextField(
              controller: _balanceCtrl,
              decoration: const InputDecoration(labelText: 'Current balance'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bankNameCtrl,
              decoration: const InputDecoration(labelText: 'Bank name (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastFourCtrl,
              decoration: const InputDecoration(labelText: 'Last 4 digits (optional)'),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
          if (_isCard) ...[
            TextField(
              controller: _balanceCtrl,
              decoration: const InputDecoration(labelText: 'Balance / amount due (optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastFourCtrl,
              decoration: const InputDecoration(labelText: 'Last 4 digits'),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitAmountCtrl,
              decoration: const InputDecoration(labelText: 'Limit (optional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            DropdownButtonFormField<String>(
              value: _limitPeriod,
              decoration: const InputDecoration(labelText: 'Limit period'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'total', child: Text('Total')),
              ],
              onChanged: (v) => setState(() => _limitPeriod = v ?? 'monthly'),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
