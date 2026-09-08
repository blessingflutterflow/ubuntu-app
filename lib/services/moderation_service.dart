import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import 'notification_service.dart';

class ModerationService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _notif     = NotificationService();

  /// Reads isAdmin fresh off the current user's own doc every time — never
  /// cached or trusted from elsewhere, so a guessed deep link can't bypass it.
  Future<bool> isCurrentUserAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['isAdmin'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Posts awaiting review, oldest-first — a moderation queue should surface
  /// the longest-waiting post first.
  Future<List<PostModel>> getPendingPosts() async {
    try {
      final snap = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'PENDING')
          .orderBy('timestamp', descending: false)
          .get();
      final posts = <PostModel>[];
      for (final doc in snap.docs) {
        try { posts.add(PostModel.fromMap(doc.data(), doc.id)); } catch (_) {}
      }
      return posts;
    } catch (_) {
      return [];
    }
  }

  Future<bool> approvePost(String postId, String authorId) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return false;
    try {
      await _firestore.collection('posts').doc(postId).update({
        'status':     'APPROVED',
        'reviewedBy': adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await _notif.sendPostApprovedNotification(postId: postId, authorId: authorId);
      // Post is only actually visible now — this is the deferred "new post" notification.
      await _notif.sendNewPostNotification(postId: postId, postOwnerId: authorId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectPost(String postId, String authorId, String reason) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) return false;
    try {
      await _firestore.collection('posts').doc(postId).update({
        'status':          'REJECTED',
        'rejectionReason': reason,
        'reviewedBy':      adminUid,
        'reviewedAt':      FieldValue.serverTimestamp(),
      });
      await _notif.sendPostRejectedNotification(postId: postId, authorId: authorId, reason: reason);
      return true;
    } catch (_) {
      return false;
    }
  }
}
