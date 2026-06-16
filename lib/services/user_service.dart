import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _storage   = FirebaseStorage.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<UserModel?> getCurrentUser() async {
    if (_uid == null) return null;
    return getUser(_uid!);
  }

  Future<void> updateProfile({
    required String displayName,
    required String username,
    required String bio,
    XFile? profileImage,
  }) async {
    final uid     = _uid!;
    final updates = <String, dynamic>{
      'displayName': displayName,
      'username':    username,
      'bio':         bio,
      'updatedAt':   FieldValue.serverTimestamp(),
    };

    if (profileImage != null) {
      final ref = _storage.ref().child('profile_pictures/$uid.jpg');
      await ref.putData(await profileImage.readAsBytes());
      updates['profileImageUrl'] = await ref.getDownloadURL();
    }

    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> follow(String targetUid) async {
    final uid = _uid!;
    if (uid == targetUid) return;
    final ts = {'timestamp': FieldValue.serverTimestamp()};
    await Future.wait([
      _firestore.collection('users').doc(targetUid).collection('followers').doc(uid).set(ts),
      _firestore.collection('users').doc(uid).collection('following').doc(targetUid).set(ts),
      _firestore.collection('users').doc(targetUid).update({'followersCount': FieldValue.increment(1)}),
      _firestore.collection('users').doc(uid).update({'followingCount': FieldValue.increment(1)}),
    ]);
  }

  Future<void> unfollow(String targetUid) async {
    final uid = _uid!;
    await Future.wait([
      _firestore.collection('users').doc(targetUid).collection('followers').doc(uid).delete(),
      _firestore.collection('users').doc(uid).collection('following').doc(targetUid).delete(),
      _firestore.collection('users').doc(targetUid).update({'followersCount': FieldValue.increment(-1)}),
      _firestore.collection('users').doc(uid).update({'followingCount': FieldValue.increment(-1)}),
    ]);
  }

  Future<bool> isFollowing(String targetUid) async {
    if (_uid == null) return false;
    final doc = await _firestore
        .collection('users').doc(targetUid).collection('followers').doc(_uid).get();
    return doc.exists;
  }

  Future<List<UserModel>> getStoriesUsers() async {
    final uid = _uid;
    if (uid == null) return [];

    final followSnap = await _firestore.collection('users').doc(uid).collection('following').get();
    final followingIds = followSnap.docs.map((d) => d.id).toList();
    if (followingIds.isEmpty) return [];

    final results = <UserModel>[];
    for (final chunk in _chunks(followingIds, 10)) {
      final snap = await _firestore.collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .where('hasActiveStory', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        results.add(UserModel.fromMap(doc.data(), doc.id));
      }
    }
    return results;
  }

  List<List<T>> _chunks<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, (i + size).clamp(0, list.length)));
    }
    return chunks;
  }
}
