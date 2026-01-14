import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // The user canceled the sign-in

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
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
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Delete Account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

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
      await _googleSignIn.signOut();

      return true;
    } catch (e) {
      print('❌ Error deleting account: $e');
      return false;
    }
  }
}
