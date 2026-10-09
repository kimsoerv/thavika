import 'dart:async';

import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Signs the user in with Google and keeps the session.
///
/// Supabase is used here for sign-in only; the data itself travels through
/// the sync engine. Without a configured project nothing here does anything
/// and the app is simply a guest app.
class AuthService extends GetxService {
  /// The signed-in user, or null for a guest.
  final user = Rxn<User>();

  /// Set when sign-in failed, for the screen to show.
  final error = RxnString();

  StreamSubscription<AuthState>? _sub;
  var _googleReady = false;

  bool get isConfigured => AppConfig.isConfigured;
  bool get isSignedIn => user.value != null;
  String? get email => user.value?.email;
  String? get accessToken => isConfigured
      ? Supabase.instance.client.auth.currentSession?.accessToken
      : null;

  Future<AuthService> init() async {
    if (!isConfigured) return this;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      final auth = Supabase.instance.client.auth;
      user.value = auth.currentUser;
      _sub = auth.onAuthStateChange.listen((s) => user.value = s.session?.user);
    } catch (e) {
      error.value = '$e';
    }
    return this;
  }

  /// Opens the Google account chooser and signs in. Returns false when the
  /// user closed it (no error to show).
  Future<bool> signInWithGoogle() async {
    error.value = null;
    try {
      final google = GoogleSignIn.instance;
      if (!_googleReady) {
        await google.initialize(
          clientId: AppConfig.googleIosClientId.isEmpty
              ? null
              : AppConfig.googleIosClientId,
          serverClientId: AppConfig.googleWebClientId.isEmpty
              ? null
              : AppConfig.googleWebClientId,
        );
        _googleReady = true;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        error.value = 'Google gave no ID token';
        return false;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      error.value = '${e.code.name}: ${e.description ?? ''}';
      return false;
    } catch (e) {
      error.value = '$e';
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (isConfigured) await Supabase.instance.client.auth.signOut();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
