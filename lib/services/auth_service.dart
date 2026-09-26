import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../promotions.dart';
import '../world_config.dart';
import '../store_shot.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  /// 테스트용 — Firebase 없이 회원/게스트를 정한다
  @visibleForTesting
  static bool? debugIsGuest;

  /// 게스트 = 로그인하지 않은 상태. 게임 맛보기만 하고 기기·서버 어디에도 아무것도 남기지 않는다.
  /// (예전 버전이 만든 익명 세션도 게스트로 본다 — 시작할 때 로그아웃시킨다)
  static bool get isGuest {
    if (debugIsGuest != null) return debugIsGuest!;
    if (kStoreShot) return true; // 스토어 스크린샷 — 늘 처음 시작한 게스트처럼
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
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
      debugPrint("Error signing in with Google: $e");
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
        debugPrint("Apple Sign In is only supported on iOS in this implementation");
        return null;
      }
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
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
          debugPrint('⚠️ Error deleting ranking records (${w.rankingMapId}): $e');
        }
      }

      // 친구 코드 — 유저 문서를 지우기 전에(거기서 내 코드를 읽는다)
      try {
        await FriendService.deleteMine(user.uid);
      } catch (e) {
        debugPrint('⚠️ Error deleting friend code: $e');
      }

      // Delete user data from Firestore (비공개 문서 먼저 — 하위 문서는 부모와 같이 지워지지 않는다)
      try {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.collection('private').doc('account').delete();
        // 플레이 기록(runs) — 400개씩 나눠 지운다
        while (true) {
          final runs = await userRef.collection('runs').limit(400).get();
          if (runs.docs.isEmpty) break;
          final batch = FirebaseFirestore.instance.batch();
          for (final d in runs.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      } catch (_) {}
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        debugPrint('✅ User data deleted from Firestore');
      } catch (e) {
        debugPrint('⚠️ Error deleting Firestore data: $e');
      }

      // Delete Firebase Auth account
      await user.delete();
      debugPrint('✅ Firebase Auth account deleted');

      // Sign out from providers
      await _googleSignIn?.signOut();

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      return false;
    }
  }
}
