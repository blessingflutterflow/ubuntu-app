import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken(cred.user!.uid);
    return cred;
  }

  Future<UserCredential> register(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserDocument({
    required String uid,
    required String email,
    required String displayName,
    required String username,
    String bio = '',
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid':              uid,
      'email':            email,
      'displayName':      displayName,
      'username':         username,
      'bio':              bio,
      'profileImageUrl':  '',
      'followersCount':   0,
      'followingCount':   0,
      'postsCount':       0,
      'isVerified':       false,
      'hasActiveStory':   false,
      'userRole':         'user',
      'createdAt':        FieldValue.serverTimestamp(),
      'updatedAt':        FieldValue.serverTimestamp(),
    });
    await _saveFcmToken(uid);
  }

  Future<bool> isUsernameAvailable(String username, {String? excludeUid}) async {
    final snap = await _firestore.collection('users').where('username', isEqualTo: username).get();
    if (snap.docs.isEmpty) return true;
    if (snap.docs.length == 1 && snap.docs.first.id == excludeUid) return true;
    return false;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({'fcmToken': token});
      }
    } catch (_) {}
  }
}
