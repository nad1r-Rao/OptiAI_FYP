import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'dart:io';
import 'dart:typed_data';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  // Auth state changes (for auto redirect, etc.)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ✅ Sign up with email and password
  Future<String?> signUp(String email, String password, {String? displayName}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user != null) {
        if (displayName != null && displayName.isNotEmpty) {
          await credential.user!.updateDisplayName(displayName);
        }
        
        if (!credential.user!.emailVerified) {
          try {
            await credential.user!.sendEmailVerification();
          } catch (e) {
          }
        }
      }
      
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // ✅ Send Email Verification
  Future<String?> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        return null;
      }
      return "User already verified or not logged in.";
    } on FirebaseAuthException catch (e) {

      return e.message;
    }
  }

  // ✅ Reload User (to refresh emailVerified status)
  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      notifyListeners();
    }
  }

  // ✅ Login with email and password
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // ✅ Logout
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  // ✅ Update Profile
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    User? user = _auth.currentUser;
    if (user != null) {
      if (displayName != null) await user.updateDisplayName(displayName);
      if (photoURL != null) await user.updatePhotoURL(photoURL);
      await user.reload();
      notifyListeners();
    }
  }

  // ✅ Upload Profile Image
  Future<String?> uploadProfileImage(Uint8List imageBytes) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      
      // Add timeout to prevent infinite loading
      await storageRef.putData(imageBytes, metadata).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("Upload timed out. Please check your internet connection.");
        },
      );

      final downloadUrl = await storageRef.getDownloadURL();
      await updateProfile(photoURL: downloadUrl);
      return downloadUrl;
    } catch (e) {

      throw e; // Rethrow to handle in UI
    }
  }

  // ✅ Change Password
  Future<void> changePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  // ✅ Delete Account
  Future<void> deleteAccount() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.delete();
      notifyListeners();
    }
  }

  // ✅ Google Sign-In
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return "Google Sign-In cancelled";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {

      return e.message;
    } catch (e, stack) {

      return "An error occurred during Google Sign-In";
    }
  }

  // ✅ Forgot Password
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);

      return null;
    } on FirebaseAuthException catch (e) {

      return e.message;
    }
  }
}
