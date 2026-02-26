import 'package:shared_preferences/shared_preferences.dart';

/// Sync schedule: when to push data to Google Drive.
enum SyncInterval {
  instant, // after every change
  daily,   // once per day (default)
  weekly,  // once per week
}

class SyncPreferences {
  SyncPreferences._();
  static final SyncPreferences instance = SyncPreferences._();

  static const _keyInterval = 'sync_interval';
  static const _keyLastSync = 'last_sync_to_drive_ms';

  Future<SyncInterval> getInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_keyInterval);
    if (s == 'instant') return SyncInterval.instant;
    if (s == 'weekly') return SyncInterval.weekly;
    return SyncInterval.daily; // default
  }

  Future<void> setInterval(SyncInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInterval, interval.name);
  }

  Future<int?> getLastSyncMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastSync);
  }

  Future<void> setLastSyncNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSync, DateTime.now().millisecondsSinceEpoch);
  }

  /// True if we should run a scheduled sync (daily = 24h passed, weekly = 7d passed).
  Future<bool> isScheduledSyncDue() async {
    final interval = await getInterval();
    if (interval == SyncInterval.instant) return false;
    final last = await getLastSyncMs();
    if (last == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;
    if (interval == SyncInterval.daily) return (now - last) >= dayMs;
    return (now - last) >= (7 * dayMs); // weekly
  }
}
