import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'accounts_screen.dart';
import 'transactions_screen.dart';
import 'lending_screen.dart';
import 'loans_screen.dart';
import 'reports_screen.dart';
import 'messages_screen.dart';
import 'offers_screen.dart';
import 'settings_screen.dart';
import '../services/theme_preferences.dart';
import '../theme/theme_notifier.dart';
import '../utils/app_animations.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    (icon: Icons.account_balance_wallet, label: 'Accounts'),
    (icon: Icons.receipt_long, label: 'Transactions'),
    (icon: Icons.people_outline, label: 'Lending'),
    (icon: Icons.credit_card, label: 'Loans'),
    (icon: Icons.bar_chart, label: 'Reports'),
  ];

  static const _screens = [
    AccountsScreen(),
    TransactionsScreen(),
    LendingScreen(),
    LoansScreen(),
    ReportsScreen(),
  ];

  void _push(Widget screen) {
    Navigator.of(context).push(
      appPageRoute(page: screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // App name – prominent
            Text(
              'Fin Manager',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(
              width: 12,
              child: Center(
                child: Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Tab/screen name – clearly secondary
            AnimatedSwitcher(
              duration: AppAnimDurations.normal,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                _tabs[_currentIndex].label,
                key: ValueKey<int>(_currentIndex),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) {
              return IconButton(
                tooltip: 'Theme',
                icon: const Icon(Icons.brightness_6_outlined),
                onPressed: () async {
                  final box = ctx.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  final offset = box.localToGlobal(Offset.zero);
                  final size = box.size;
                  final selected = await showMenu<Object>(
                    context: ctx,
                    position: RelativeRect.fromLTRB(
                      offset.dx,
                      offset.dy + size.height,
                      offset.dx + size.width,
                      offset.dy + size.height + 1,
                    ),
                    items: [
                      const PopupMenuItem(value: ThemeMode.light, child: Row(children: [Icon(Icons.light_mode, size: 20), SizedBox(width: 12), Text('Light')])),
                      const PopupMenuItem(value: ThemeMode.dark, child: Row(children: [Icon(Icons.dark_mode, size: 20), SizedBox(width: 12), Text('Dark')])),
                      const PopupMenuItem(value: ThemeMode.system, child: Row(children: [Icon(Icons.brightness_auto, size: 20), SizedBox(width: 12), Text('System')])),
                      const PopupMenuDivider(),
                      PopupMenuItem(value: ThemePreferences.styleDefault, child: Row(children: [Icon(Icons.palette_outlined, size: 20), SizedBox(width: 12), Text('Default style')])),
                      PopupMenuItem(value: ThemePreferences.styleAesthetic, child: Row(children: [Icon(Icons.style, size: 20), SizedBox(width: 12), Text('Aesthetic style')])),
                    ],
                  );
                  if (selected != null) {
                    HapticFeedback.lightImpact();
                    if (selected is ThemeMode) {
                      ThemeNotifier.instance.setThemeMode(selected);
                    } else if (selected is String) {
                      ThemeNotifier.instance.setThemeStyle(selected);
                    }
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _push(const MessagesScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () => _push(const OffersScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: AppAnimDurations.normal,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: ThemeNotifier.instance.isAesthetic
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                  child: SafeArea(
                    top: false,
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (i) => setState(() => _currentIndex = i),
                      destinations: _tabs
                          .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
                          .toList(),
                    ),
                  ),
                ),
              ),
            )
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              destinations: _tabs
                  .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
                  .toList(),
            ),
    );
  }
}
