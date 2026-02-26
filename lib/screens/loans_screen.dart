import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/loan.dart';
import '../services/drive_sync_service.dart';
import '../utils/app_animations.dart';
import '../widgets/empty_state.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _save() async {
    try {
      await _drive.saveLoans();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _openAdd() {
    Navigator.of(context).push(
      appPageRoute(
        page: _LoanFormScreen(
          onSave: (l) async {
            _drive.addLoan(l);
            await _save();
          },
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _openEdit(int index) {
    final l = _drive.loans[index];
    Navigator.of(context).push(
      appPageRoute(
        page: _LoanFormScreen(
          initial: l,
          onSave: (updated) async {
            _drive.updateLoan(index, updated);
            await _save();
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
    final list = _drive.loans;
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
          if (mounted && _drive.loans.isNotEmpty) {
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
                    icon: Icons.credit_card_outlined,
                    title: 'Nothing is available',
                    subtitle: 'Track loans you\'ve taken.',
                    action: FilledButton.icon(
                      onPressed: _openAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add loan'),
                    ),
                  ),
                ),
              )
            : ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final l = list[i];
            return StaggeredListItem(
              index: i,
              itemCount: list.length,
              controller: _listAnimController,
              child: Card(
                child: ListTile(
                  title: Text(l.lenderName),
                  subtitle: Text('${l.amount.toStringAsFixed(2)} ${l.currency} · ${l.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEdit(i),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_loans',
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoanFormScreen extends StatefulWidget {
  final Loan? initial;
  final void Function(Loan) onSave;

  const _LoanFormScreen({this.initial, required this.onSave});

  @override
  State<_LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<_LoanFormScreen> {
  final _lenderCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  DateTime _takenAt = DateTime.now();
  DateTime? _dueAt;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final l = widget.initial!;
      _lenderCtrl.text = l.lenderName;
      _amountCtrl.text = l.amount.toString();
      _notesCtrl.text = l.notes ?? '';
      _interestCtrl.text = l.interestRate?.toString() ?? '';
      _takenAt = l.takenAt;
      _dueAt = l.dueAt;
      _status = l.status;
    }
  }

  @override
  void dispose() {
    _lenderCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _lenderCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter lender name')));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final interest = double.tryParse(_interestCtrl.text.trim());
    final l = Loan(
      id: widget.initial?.id ?? const Uuid().v4(),
      lenderName: name,
      amount: amount,
      takenAt: _takenAt,
      dueAt: _dueAt,
      status: _status,
      interestRate: interest,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(l);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add loan' : 'Edit loan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _lenderCtrl,
            decoration: const InputDecoration(labelText: 'Lender name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _interestCtrl,
            decoration: const InputDecoration(labelText: 'Interest rate % (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('Taken: ${_takenAt.toString().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _takenAt, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (p != null) setState(() => _takenAt = p);
            },
          ),
          ListTile(
            title: Text(_dueAt == null ? 'Due: (optional)' : 'Due: ${_dueAt.toString().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _dueAt ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
              if (p != null) setState(() => _dueAt = p);
            },
          ),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'active'),
          ),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }
}
