import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import '../config/app_config.dart';

/// Google Sign-In for Fin Manager. Used for Drive sync (CSV).
/// Scopes include Drive file access so the app can read/write its folder.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const _driveScope = 'https://www.googleapis.com/auth/drive.file';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_driveScope],
    serverClientId: AppConfig.googleSignInServerClientId,
  );

  StreamSubscription<GoogleSignInAccount?>? _subscription;
  final _currentUserController = StreamController<GoogleSignInAccount?>.broadcast();

  /// Stream of current user: null when signed out, account when signed in.
  Stream<GoogleSignInAccount?> get currentUserStream => _currentUserController.stream;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Call once at app start to listen to sign-in changes.
  void init() {
    _currentUserController.add(_googleSignIn.currentUser);
    _subscription = _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUserController.add(account);
    });
  }

  /// Sign in with Google. Returns account on success, throws on failure/cancel.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Authenticated HTTP client for Google APIs (e.g. Drive). Returns null if not signed in.
  Future<dynamic> getAuthenticatedClient() async {
    return _googleSignIn.authenticatedClient();
  }

  void dispose() {
    _subscription?.cancel();
    _currentUserController.close();
  }
}
