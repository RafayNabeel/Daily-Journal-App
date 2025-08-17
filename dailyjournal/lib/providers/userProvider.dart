import 'package:dailyjournal/models/userModel.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthState {
  loading,
  authenticated,
  unauthenticated,
  guest,
}

class UserProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  AuthState _authState = AuthState.loading;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  User? get currentUser => _currentUser;
  AuthState get authState => _authState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  bool get isGuest => _authState == AuthState.guest;

  UserProvider() {
    _initializeUser();
  }

  // Initialize user and listen to auth state changes
  Future<void> _initializeUser() async {
    _setLoading(true);

    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUserFromFirestore(firebaseUser.uid);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final isGuest = prefs.getBool('is_guest') ?? false;

        if (isGuest) {
          _currentUser = User.guest();
          _authState = AuthState.guest;
        } else {
          _currentUser = null;
          _authState = AuthState.unauthenticated;
        }
      }
      _setLoading(false);
    });
  }

  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _currentUser = User.fromJson({
          ...data,
          'id': uid,
        });
        _authState = AuthState.authenticated;
      } else {
        await signOut();
      }
    } catch (e) {
      _setError('Failed to load user data: ${e.toString()}');
      await signOut();
    }
  }

  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (!_isValidEmail(email)) {
        throw firebase_auth.FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      if (!_isValidPassword(password)) {
        throw firebase_auth.FirebaseAuthException(
          code: 'weak-password',
          message: 'Password must be at least 8 characters long',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.toLowerCase(),
        password: password,
      );

      if (credential.user != null) {
        final userData = {
          'email': email.toLowerCase(),
          'firstName': firstName,
          'lastName': lastName,
          'profileImageUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isEmailVerified': false,
        };

        await _firestore.collection('users').doc(credential.user!.uid).set(userData);
        await credential.user!.sendEmailVerification();
        return true;
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (_) {
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (!_isValidEmail(email)) {
        throw firebase_auth.FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      if (password.isEmpty) {
        throw firebase_auth.FirebaseAuthException(
          code: 'missing-password',
          message: 'Password is required',
        );
      }

      await _auth.signInWithEmailAndPassword(
        email: email.toLowerCase(),
        password: password,
      );

      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (_) {
      _setError('An unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Continue as guest
  Future<void> continueAsGuest() async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = User.guest();
      _authState = AuthState.guest;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', true);
    } catch (_) {
      _setError('Failed to continue as guest');
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);

    try {
      await _auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_guest');

      _currentUser = null;
      _authState = AuthState.unauthenticated;
      _clearError();
    } catch (_) {
      _setError('Failed to sign out');
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      if (!_isValidEmail(email)) {
        throw firebase_auth.FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      await _auth.sendPasswordResetEmail(email: email.toLowerCase());
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (_) {
      _setError('Failed to send password reset email');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? profileImageUrl,
  }) async {
    if (_currentUser == null || _authState != AuthState.authenticated) return false;

    _setLoading(true);
    _clearError();

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (firstName != null) updates['firstName'] = firstName;
      if (lastName != null) updates['lastName'] = lastName;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      await _firestore.collection('users').doc(_currentUser!.id).update(updates);

      _currentUser = _currentUser!.copyWith(
        firstName: firstName,
        lastName: lastName,
        profileImageUrl: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (_) {
      _setError('Failed to update profile');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.sendEmailVerification();
      return true;
    } catch (_) {
      _setError('Failed to send email verification');
      return false;
    }
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      if (user.emailVerified && _currentUser != null) {
        await _firestore.collection('users').doc(user.uid).update({'isEmailVerified': true});
        _currentUser = _currentUser!.copyWith(isEmailVerified: true);
        notifyListeners();
      }
    } catch (_) {
      // silent fail
    }
  }

  // Helpers
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 8;
  }

  String _getFirebaseErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'No account found with this email address';
      case 'wrong-password': return 'Incorrect password';
      case 'email-already-in-use': return 'An account already exists with this email address';
      case 'invalid-email': return 'Please enter a valid email address';
      case 'weak-password': return 'Password should be at least 8 characters';
      case 'user-disabled': return 'This account has been disabled';
      case 'too-many-requests': return 'Too many failed attempts. Please try again later';
      case 'operation-not-allowed': return 'This sign-in method is not enabled';
      case 'network-request-failed': return 'Network error. Please check your connection';
      default: return e.message ?? 'An error occurred during authentication';
    }
  }
}
