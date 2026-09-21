import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../world_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  /// 게스트(익명) 로그인. 세션이 기기에 저장되므로 앱을 껐다 켜도
  /// 로그인 화면을 다시 보지 않고, 통계/업적을 uid 기준으로 이어갈 수 있다.
  Future<UserCredential?> signInAnonymously() async {
    try {
      if (_auth.currentUser != null) return null; // 이미 세션 있음
      return await _auth.signInAnonymously();
    } catch (e) {
      print("Error signing in anonymously: $e");
      return null;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      }

      if (_googleSignIn == null) return null;
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // Sign in with Apple
  // Returns a Map with 'credential' and 'fullName' keys
  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final OAuthProvider res = OAuthProvider('apple.com');
        final OAuthCredential credential = res.credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        // Extract full name (only available on first sign-in)
        String? fullName;
        if (appleCredential.givenName != null) {
          fullName = appleCredential.givenName;
        }

        return {
          'credential': userCredential,
          'fullName': fullName,
        };
      } else {
        // Fallback for Android or other platforms if needed, though usually Apple Sign In on Android uses a web flow
        // For now, restricting to iOS
        print("Apple Sign In is only supported on iOS in this implementation");
        return null;
      }
    } catch (e) {
      print("Error signing in with Apple: $e");
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }

  // Delete Account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 랭킹 기록 삭제 — 존별 리더보드(maps/{mapId}/records)에서 내 기록을 모두 지운다.
      // (firestore.rules: 본인 userId 기록만 삭제 허용) docs/privacy.html §3 과 일치해야 한다.
      for (final w in WorldData.worlds) {
        try {
          final mine = await FirebaseFirestore.instance
              .collection('maps')
              .doc(w.rankingMapId)
              .collection('records')
              .where('userId', isEqualTo: user.uid)
              .get();
          for (final d in mine.docs) {
            await d.reference.delete();
          }
        } catch (e) {
          print('⚠️ Error deleting ranking records (${w.rankingMapId}): $e');
        }
      }

      // Delete user data from Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        print('✅ User data deleted from Firestore');
      } catch (e) {
        print('⚠️ Error deleting Firestore data: $e');
      }

      // Delete Firebase Auth account
      await user.delete();
      print('✅ Firebase Auth account deleted');

      // Sign out from providers
      await _googleSignIn?.signOut();

      return true;
    } catch (e) {
      print('❌ Error deleting account: $e');
      return false;
    }
  }
}
