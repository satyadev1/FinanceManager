import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/drive_sync_service.dart';
import '../widgets/empty_state.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final DriveSyncService _drive = DriveSyncService.instance;

  /// Filter: null = all, 'unread' = unread only, or type (info, offer, reminder)
  String? _filter;

  List<AppNotification> get _filtered {
    var list = _drive.notifications;
    if (_filter == 'unread') {
      list = list.where((n) => !n.read).toList();
    } else if (_filter != null && _filter!.isNotEmpty) {
      list = list.where((n) => n.type == _filter).toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _drive.addListener(_onDriveUpdated);
    _refreshAndMarkRead();
  }

  @override
  void dispose() {
    _drive.removeListener(_onDriveUpdated);
    super.dispose();
  }

  void _onDriveUpdated() {
    if (mounted) setState(() {});
  }

  /// Refresh notifications from Drive/DB and mark all as read so the list auto-updates.
  Future<void> _refreshAndMarkRead() async {
    await _drive.refreshNotifications();
    await _drive.markAllNotificationsAsRead();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            initialValue: _filter,
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: 'unread', child: Text('Unread only')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'info', child: Text('Type: Info')),
              const PopupMenuItem(value: 'offer', child: Text('Type: Offer')),
              const PopupMenuItem(value: 'reminder', child: Text('Type: Reminder')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAndMarkRead,
        child: list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Nothing is available',
                      subtitle: _filter != null
                          ? 'No messages match the current filter.'
                          : 'You have no messages yet.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                return Dismissible(
                  key: Key(n.id ?? 'msg_${identityHashCode(n)}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Theme.of(context).colorScheme.error,
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Dismiss message?'),
                        content: const Text(
                          'This will remove the message. You can filter by type to hide irrelevant messages instead.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) async {
                    final globalIdx = _drive.notifications.indexWhere((x) => x == n);
                    if (globalIdx >= 0) {
                      _drive.removeNotificationAt(globalIdx);
                      await _drive.saveNotifications();
                      if (mounted) setState(() {});
                    }
                  },
                  child: Card(
                    child: ListTile(
                      title: Text(n.title),
                      subtitle: Text(n.body),
                      leading: Icon(
                        n.read ? Icons.mark_email_read : Icons.mark_email_unread,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () async {
                        final globalIdx = _drive.notifications.indexWhere((x) => x == n);
                        if (globalIdx >= 0 && !n.read) {
                          await _drive.markNotificationAsRead(globalIdx);
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Dismiss (not relevant)',
                        onPressed: () async {
                          final globalIdx = _drive.notifications.indexWhere((x) => x == n);
                          if (globalIdx >= 0) {
                            _drive.removeNotificationAt(globalIdx);
                            await _drive.saveNotifications();
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
