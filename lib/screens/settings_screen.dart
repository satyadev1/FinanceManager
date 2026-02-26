import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/google_auth_service.dart';
import '../services/drive_sync_service.dart';
import '../services/sync_preferences.dart';
import '../services/sms_import_service.dart';
import '../services/theme_preferences.dart';
import '../theme/theme_notifier.dart';
import 'sms_import_review_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GoogleAuthService _auth = GoogleAuthService.instance;
  bool _loading = false;
  String? _message;
  SyncInterval _syncInterval = SyncInterval.daily;
  int? _lastSyncMs;
  bool _syncing = false;
  bool _smsImporting = false;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await _auth.signIn();
      if (mounted) {
        setState(() => _loading = false);
        if (_auth.currentUser != null) {
          await DriveSyncService.instance.loadAll();
          await _loadSyncPrefs();
          if (mounted) setState(() {});
        }
      }
    } catch (e, st) {
      if (mounted) setState(() {
        _loading = false;
        final err = e.toString();
        if (err.contains('ApiException: 10') || err.contains('DEVELOPER_ERROR') || err.contains('sign_in_failed')) {
          _message = 'Sign-in failed (developer config). '
              'In Google Cloud Console add an Android OAuth client with package name com.example.finance_manager '
              'and your app SHA-1 (run in android folder: ./gradlew signingReport). '
              'Optionally set AppConfig.googleSignInServerClientId to your Web client ID.';
        } else {
          _message = err;
        }
      });
      debugPrint('[Google Sign-In] $e\n$st');
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _loadSyncPrefs() async {
    final interval = await SyncPreferences.instance.getInterval();
    final last = await SyncPreferences.instance.getLastSyncMs();
    if (mounted) setState(() {
      _syncInterval = interval;
      _lastSyncMs = last;
    });
  }

  Future<void> _setSyncInterval(SyncInterval value) async {
    await SyncPreferences.instance.setInterval(value);
    if (mounted) setState(() => _syncInterval = value);
  }

  Future<void> _syncNow() async {
    setState(() { _syncing = true; _message = null; });
    try {
      await DriveSyncService.instance.syncNow();
      await _loadSyncPrefs();
      final err = DriveSyncService.instance.lastSyncError;
      if (mounted && err != null) setState(() => _message = 'Sync failed: $err');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _importFromSms() async {
    debugPrint('[SMS] Import button tapped');
    setState(() => _message = null);
    if (!isSmsImportSupported) {
      setState(() => _message = 'SMS import is only available on Android.');
      return;
    }
    final granted = await requestSmsPermission();
    if (!mounted) return;
    if (!granted) {
      await openAppSettings();
      setState(() => _message = 'SMS permission needed. Please turn on "SMS" or "Messages" in the app permissions screen that opened.');
      return;
    }

    setState(() => _smsImporting = true);
    debugPrint('[SMS] Starting import...');
    try {
      final result = await importFromSms();
      if (!mounted) return;
      setState(() => _smsImporting = false);

      if (result.notSupported) {
        setState(() => _message = 'SMS import is only available on Android.');
        return;
      }
      if (result.permissionDenied) {
        setState(() => _message = 'SMS permission denied. Enable it in Settings → Apps → Fin Manager → Permissions.');
        return;
      }
      if (result.error != null) {
        setState(() => _message = 'Error: ${result.error}');
        return;
      }

      debugPrint('[SMS] Scanned ${result.messageCount} messages, found ${result.transactions.length} transactions, ${result.detectedAccounts.length} accounts');

      if (result.messageCount == 0) {
        setState(() => _message = 'No messages found in inbox.');
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SmsImportReviewScreen(result: result)),
      );
      if (saved == true && mounted) {
        setState(() => _message = 'Import complete!');
      }
    } catch (e) {
      debugPrint('[SMS] Exception: $e');
      if (mounted) setState(() {
        _smsImporting = false;
        _message = 'Error: $e';
      });
    }
  }

  String _formatLastSync(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  void initState() {
    super.initState();
    if (_auth.currentUser != null) _loadSyncPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _auth.currentUser != null;

    final themeNotifier = ThemeNotifier.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.light_mode),
                  title: const Text('Light'),
                  subtitle: const Text('White / light background'),
                  trailing: Radio<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        themeNotifier.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeMode(ThemeMode.light);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode),
                  title: const Text('Dark'),
                  subtitle: const Text('Dark background'),
                  trailing: Radio<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        themeNotifier.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeMode(ThemeMode.dark);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.brightness_auto),
                  title: const Text('System'),
                  subtitle: const Text('Follow device setting'),
                  trailing: Radio<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        themeNotifier.setThemeMode(value);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeMode(ThemeMode.system);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Theme style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Default'),
                  subtitle: const Text('Blue accent, standard look'),
                  trailing: Radio<String>(
                    value: ThemePreferences.styleDefault,
                    groupValue: themeNotifier.themeStyle,
                    onChanged: (String? value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        themeNotifier.setThemeStyle(value);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeStyle(ThemePreferences.styleDefault);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.style),
                  title: const Text('Aesthetic'),
                  subtitle: const Text('Orange accent, clean Overview / Analytics look'),
                  trailing: Radio<String>(
                    value: ThemePreferences.styleAesthetic,
                    groupValue: themeNotifier.themeStyle,
                    onChanged: (String? value) {
                      if (value != null) {
                        HapticFeedback.lightImpact();
                        themeNotifier.setThemeStyle(value);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeNotifier.setThemeStyle(ThemePreferences.styleAesthetic);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Google account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (signedIn) ...[
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(_auth.currentUser!.email),
              subtitle: const Text('Data syncs to Google Drive (FinManager folder) only when signed in.'),
            ),
            const SizedBox(height: 16),
            const Text('Sync frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            SegmentedButton<SyncInterval>(
              segments: const [
                ButtonSegment(value: SyncInterval.instant, label: Text('Instant'), icon: Icon(Icons.sync)),
                ButtonSegment(value: SyncInterval.daily, label: Text('Daily'), icon: Icon(Icons.today)),
                ButtonSegment(value: SyncInterval.weekly, label: Text('Weekly'), icon: Icon(Icons.date_range)),
              ],
              selected: {_syncInterval},
              onSelectionChanged: (Set<SyncInterval> selected) {
                _setSyncInterval(selected.first);
              },
            ),
            const SizedBox(height: 8),
            if (_lastSyncMs != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Last sync: ${_formatLastSync(_lastSyncMs!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            FilledButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload),
              label: Text(_syncing ? 'Syncing…' : 'Sync now'),
            ),
            if (DriveSyncService.instance.lastSyncError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sync error: ${DriveSyncService.instance.lastSyncError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _signOut,
              child: const Text('Sign out'),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('Not signed in'),
              subtitle: const Text('Data stays on this device only. Sign in to sync to Google Drive.'),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _signIn,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
              label: Text(_loading ? 'Signing in…' : 'Sign in with Google'),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Import from SMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
            'Read bank SMS and import transactions automatically. Works without sign-in.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _smsImporting ? null : _importFromSms,
            icon: _smsImporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sms),
            label: Text(_smsImporting ? 'Reading & analysing…' : 'Import from SMS'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
