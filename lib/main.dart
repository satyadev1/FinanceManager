import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:indian_sms_filter/indian_sms_filter.dart';
import 'engine/sms_intelligence_engine.dart';
import 'screens/main_shell.dart';
import 'services/database_service.dart';
import 'services/drive_sync_service.dart';
import 'services/google_auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register Indian SMS plugin for TRAI sender filtering, UPI patterns, etc.
  registerSmsRegionPlugin(IndianSmsPlugin.instance);
  if (!kIsWeb) {
    await DatabaseService.instance.database;
  }
  GoogleAuthService.instance.init();
  await DriveSyncService.instance.loadAll();
  await ThemeNotifier.instance.load();
  runApp(const FinManagerApp());
}

class FinManagerApp extends StatelessWidget {
  const FinManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) {
        final notifier = ThemeNotifier.instance;
        final themeMode = notifier.themeMode;
        final useAesthetic = notifier.isAesthetic;
        final theme = useAesthetic ? AppTheme.themeAestheticLight : AppTheme.themeLight;
        final darkTheme = useAesthetic ? AppTheme.themeAestheticDark : AppTheme.themeDark;
        return MaterialApp(
          title: 'Fin Manager',
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey('$themeMode-$useAesthetic'),
              child: const MainShell(),
            ),
          ),
        );
      },
    );
  }
}
