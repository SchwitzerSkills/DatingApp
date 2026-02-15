import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    // Google: lokale Session trennen
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// -----------------------
  /// GOOGLE SIGN-IN
  /// -----------------------
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return _auth.signInWithPopup(googleProvider);
    }

    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    if (gUser == null) {
      throw Exception("Google Sign-In abgebrochen");
    }

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// -----------------------
  /// APPLE SIGN-IN (iOS/Web)
  /// -----------------------
  Future<UserCredential> signInWithApple({
    // Für WEB musst du das setzen:
    String? webClientId,
    Uri? webRedirectUri,
  }) async {
    // Nonce für Apple -> Firebase
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final bool isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw Exception("Apple Sign-In ist auf diesem Gerät nicht verfügbar");
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
      webAuthenticationOptions: kIsWeb
          ? WebAuthenticationOptions(
              clientId: webClientId ?? "DEIN_SERVICE_ID_CLIENT_ID",
              redirectUri: webRedirectUri ?? Uri.parse("https://DEINE-DOMAIN.web.app/__/auth/handler"),
            )
          : null,
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(oauthCredential);
  }

  /// Helpers
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
