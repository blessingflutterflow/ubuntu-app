import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/comment_model.dart';
import 'notification_service.dart';

class CommentService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _notif     = NotificationService();
  final _uuid      = const Uuid();

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<CommentModel>> commentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => CommentModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addComment(String postId, String text, String postOwnerId) async {
    final uid = _uid;
    if (uid == null) return;

    final userData = await _firestore.collection('users').doc(uid).get();
    final data     = userData.data() ?? {};
    final commentId = _uuid.v4();

    await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).set({
      'id':                  commentId,
      'postId':              postId,
      'userId':              uid,
      'username':            data['username'] ?? 'user',
      'userProfileImageUrl': data['profileImageUrl'],
      'text':                text,
      'timestamp':           FieldValue.serverTimestamp(),
      'likesCount':          0,
    });

    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });

    _notif.sendCommentNotification(
      postId:      postId,
      postOwnerId: postOwnerId,
      commentId:   commentId,
      commentText: text,
    );
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).delete();
    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(-1),
    });
  }
}
