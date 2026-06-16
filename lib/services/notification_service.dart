import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Transaction;

class NotificationService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _rtdb      = FirebaseDatabase.instance;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> sendLikeNotification({required String postId, required String postOwnerId}) async {
    final uid = _uid;
    if (uid == null || uid == postOwnerId) return;
    try {
      final userData = await _getUserData(uid);
      final postDoc  = await _firestore.collection('posts').doc(postId).get();
      final thumbUrl = (postDoc.data()?['mediaUrls'] as List?)?.firstOrNull as String?
          ?? postDoc.data()?['videoThumbnailUrl'] as String?;

      await _save(
        type:                  'LIKE',
        senderId:              uid,
        senderUsername:        userData['username'] ?? 'Someone',
        senderProfileImageUrl: userData['profileImageUrl'] as String?,
        receiverId:            postOwnerId,
        postId:                postId,
        message:               '${userData['username']} liked your post',
        postThumbnailUrl:      thumbUrl,
      );
    } catch (_) {}
  }

  Future<void> sendCommentNotification({
    required String postId,
    required String postOwnerId,
    required String commentId,
    required String commentText,
  }) async {
    final uid = _uid;
    if (uid == null || uid == postOwnerId) return;
    try {
      final userData = await _getUserData(uid);
      final truncated = commentText.length > 50 ? '${commentText.substring(0, 50)}...' : commentText;
      await _save(
        type:                  'COMMENT',
        senderId:              uid,
        senderUsername:        userData['username'] ?? 'Someone',
        senderProfileImageUrl: userData['profileImageUrl'] as String?,
        receiverId:            postOwnerId,
        postId:                postId,
        commentId:             commentId,
        message:               '${userData['username']} commented: $truncated',
      );
    } catch (_) {}
  }

  Future<void> sendFollowNotification({required String followedUserId}) async {
    final uid = _uid;
    if (uid == null || uid == followedUserId) return;
    try {
      final userData = await _getUserData(uid);
      await _save(
        type:                  'FOLLOW',
        senderId:              uid,
        senderUsername:        userData['username'] ?? 'Someone',
        senderProfileImageUrl: userData['profileImageUrl'] as String?,
        receiverId:            followedUserId,
        message:               '${userData['username']} started following you',
      );
    } catch (_) {}
  }

  Future<void> sendNewPostNotification({required String postId, required String postOwnerId}) async {
    try {
      final userData  = await _getUserData(postOwnerId);
      final followers = await _getFollowers(postOwnerId);
      if (followers.isEmpty) return;

      final postDoc  = await _firestore.collection('posts').doc(postId).get();
      final thumbUrl = (postDoc.data()?['mediaUrls'] as List?)?.firstOrNull as String?
          ?? postDoc.data()?['videoThumbnailUrl'] as String?;

      for (final followerId in followers) {
        await _save(
          type:                  'NEW_POST',
          senderId:              postOwnerId,
          senderUsername:        userData['username'] ?? 'Someone',
          senderProfileImageUrl: userData['profileImageUrl'] as String?,
          receiverId:            followerId,
          postId:                postId,
          message:               '${userData['username']} posted something new',
          postThumbnailUrl:      thumbUrl,
        );
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String notifId) async {
    await _firestore.collection('notifications').doc(notifId).update({'isRead': true});
    final uid = _uid;
    if (uid == null) return;
    final ref = _rtdb.ref('user_notifications/$uid/unread_count');
    final snap = await ref.get();
    final count = (snap.value as int?) ?? 0;
    if (count > 0) await ref.set(count - 1);
  }

  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _firestore.collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
    await _rtdb.ref('user_notifications/$uid/unread_count').set(0);
  }

  Stream<int> unreadCountStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _rtdb.ref('user_notifications/$uid/unread_count').onValue.map((e) {
      return (e.snapshot.value as int?) ?? 0;
    });
  }

  Future<void> _save({
    required String type,
    required String senderId,
    required String senderUsername,
    String? senderProfileImageUrl,
    required String receiverId,
    String? postId,
    String? commentId,
    required String message,
    String? postThumbnailUrl,
  }) async {
    final docRef = _firestore.collection('notifications').doc();
    await docRef.set({
      'id':                    docRef.id,
      'type':                  type,
      'senderId':              senderId,
      'senderUsername':        senderUsername,
      'senderProfileImageUrl': senderProfileImageUrl,
      'receiverId':            receiverId,
      'postId':                postId,
      'commentId':             commentId,
      'message':               message,
      'postThumbnailUrl':      postThumbnailUrl,
      'isRead':                false,
      'timestamp':             FieldValue.serverTimestamp(),
    });
    final ref   = _rtdb.ref('user_notifications/$receiverId/unread_count');
    final snap  = await ref.get();
    final count = (snap.value as int?) ?? 0;
    await ref.set(count + 1);
  }

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  Future<List<String>> _getFollowers(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).collection('followers').get();
    return snap.docs.map((d) => d.id).toList();
  }
}
