import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import 'notification_service.dart';

class CommentService {
  final _db    = FirebaseFirestore.instance;
  final _auth  = FirebaseAuth.instance;
  final _notif = NotificationService();

  String? get _uid => _auth.currentUser?.uid;

  // Top-level 'comments' collection — same as Android app
  Stream<List<CommentModel>> commentsStream(String postId) {
    return _db
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => CommentModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        });
  }

  Future<void> addComment({
    required String postId,
    required String text,
    required String postOwnerId,
    String? imageUrl,
    String? parentCommentId,
    String? parentCommentUserId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final userDoc = await _db.collection('users').doc(uid).get();
    final u = userDoc.data() ?? {};

    final ref = _db.collection('comments').doc();
    await ref.set({
      'postId':           postId,
      'userId':           uid,
      'username':         u['username'] ?? 'user',
      'userProfileImage': u['profileImageUrl'] ?? '',
      'text':             text,
      'imageUrl':         imageUrl,
      'audioUrl':         null,
      'parentCommentId':  parentCommentId,
      'likesCount':       0,
      'likedBy':          [],
      'createdAt':        FieldValue.serverTimestamp(),
    });

    // Increment post comment count
    await _db.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });

    // Send notification
    if (parentCommentId != null && parentCommentUserId != null && parentCommentUserId != uid) {
      _notif.sendCommentNotification(
        postId:      postId,
        postOwnerId: parentCommentUserId,
        commentId:   ref.id,
        commentText: text,
      );
    } else if (parentCommentId == null && postOwnerId.isNotEmpty && postOwnerId != uid) {
      _notif.sendCommentNotification(
        postId:      postId,
        postOwnerId: postOwnerId,
        commentId:   ref.id,
        commentText: text,
      );
    }
  }

  Future<void> toggleLike(String commentId, List<String> likedBy) async {
    final uid = _uid;
    if (uid == null) return;
    final isLiked = likedBy.contains(uid);
    await _db.collection('comments').doc(commentId).update({
      'likedBy':    isLiked ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }
}
