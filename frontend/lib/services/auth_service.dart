import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  /// Stream of Firebase auth state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in Firebase user (may be null).
  static User? get currentUser => _auth.currentUser;

  /// Sign in with email and password.
  /// Returns the UserModel if successful, throws on error.
  static Future<UserModel> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = cred.user!.uid;
    final userDoc = await _db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      // Auth exists but no Firestore profile yet — sign out and throw
      await _auth.signOut();
      throw Exception(
        'User profile not found. Run "Seed Demo Data" from the Admin screen first.',
      );
    }

    return UserModel.fromFirestore(userDoc);
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch current user's Firestore profile.
  static Future<UserModel?> getCurrentUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    return UserModel.fromFirestore(doc);
  }

  /// Stream of the current user's Firestore profile.
  /// Updates in real time if the document changes.
  static Stream<UserModel?> currentUserProfileStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }
}
