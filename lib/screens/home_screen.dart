import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/sync_service.dart';
import '../services/google_auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SyncService _sync = SyncService.instance;
  List<Transaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndSubscribe();
  }

  Future<void> _loadAndSubscribe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _sync.subscribeToTransactions((list) {
        if (mounted) setState(() => _transactions = list);
      });
      final list = await _sync.getTransactions();
      if (mounted) setState(() => _transactions = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTransaction() async {
    final t = Transaction(
      title: 'Sample',
      amount: 0,
      date: DateTime.now(),
    );
    try {
      await _sync.addTransaction(t);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fin Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) async {
              if (value == 'signout') {
                await GoogleAuthService.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadAndSubscribe,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _transactions.length,
                  itemBuilder: (context, i) {
                    final t = _transactions[i];
                    return Card(
                      child: ListTile(
                        title: Text(t.title),
                        subtitle: Text(t.date.toString().substring(0, 10)),
                        trailing: Text(
                          '${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_home',
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}
