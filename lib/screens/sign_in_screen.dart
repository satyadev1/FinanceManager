import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with SingleTickerProviderStateMixin {
  final GoogleAuthService _auth = GoogleAuthService.instance;
  bool _loading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _iconAnim;
  late Animation<double> _titleAnim;
  late Animation<double> _subtitleAnim;
  late Animation<double> _buttonAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _iconAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0, 0.28, curve: Curves.easeOutCubic),
    );
    _titleAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.18, 0.45, curve: Curves.easeOutCubic),
    );
    _subtitleAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.32, 0.55, curve: Curves.easeOutCubic),
    );
    _buttonAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _animController.forward());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _auth.signIn();
      if (account == null && mounted) {
        // User cancelled
        setState(() => _loading = false);
        return;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        setState(() {
          _loading = false;
          if (err.contains('ApiException: 10') || err.contains('DEVELOPER_ERROR') || err.contains('sign_in_failed')) {
            _error = 'Sign-in failed: check app config. In Google Cloud Console add an Android OAuth client '
                '(package: com.example.finance_manager, SHA-1 from android: ./gradlew signingReport). '
                'Optionally set AppConfig.googleSignInServerClientId to your Web client ID.';
          } else {
            _error = err;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _iconAnim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.6, end: 1).animate(_iconAnim),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 56,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _titleAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(_titleAnim),
                      child: Text(
                        'Fin Manager',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _subtitleAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(_subtitleAnim),
                      child: Text(
                        'Sign in to sync your data with Google Drive',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  FadeTransition(
                    opacity: _buttonAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(_buttonAnim),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: _loading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 22),
                      label: Text(
                        _loading ? 'Signing in…' : 'Sign in with Google',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
