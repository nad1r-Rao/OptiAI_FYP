import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

/// A provider class for managing user authentication with Firebase.
///
/// This class encapsulates the logic for signing up, logging in, logging out,
/// and listening to authentication state changes using [FirebaseAuth]. It uses
/// the [ChangeNotifier] mixin to notify listeners of changes, such as after a logout.
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Gets the currently authenticated user.
  ///
  /// Returns the [User] object if a user is signed in, otherwise returns `null`.
  User? get user => _auth.currentUser;

  /// A stream that emits the current user when the authentication state changes.
  ///
  /// This can be used to automatically redirect users or update the UI when
  /// they sign in or out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs up a new user with the given email and password.
  ///
  /// [email] The user's email address.
  /// [password] The user's chosen password.
  ///
  /// Returns `null` on success, or an error message string if the signup fails.
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Logs in an existing user with the given email and password.
  ///
  /// [email] The user's email address.
  /// [password] The user's password.
  ///
  /// Returns `null` on success, or an error message string if the login fails.
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Logs out the current user.
  ///
  /// Notifies listeners after the sign-out operation is complete.
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  
}
