import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/livestream_model.dart';
import 'notification_service.dart';

class LivestreamService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;
  final _rtdb      = FirebaseDatabase.instance;
  final _notif     = NotificationService();
  final _uuid      = const Uuid();

  String? get _uid => _auth.currentUser?.uid;

  Future<String?> createLivestream(String title) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final userData = await _getUserData(uid);
      final streamId = _uuid.v4();

      await _firestore.collection('livestreams').doc(streamId).set({
        'id':                   streamId,
        'broadcasterId':        uid,
        'broadcasterUsername':  userData['username'] ?? 'Someone',
        'broadcasterAvatarUrl': userData['profileImageUrl'],
        'channelName':          streamId,
        'title':                title,
        'status':               'LIVE',
        'startedAt':            FieldValue.serverTimestamp(),
        'endedAt':              null,
        'endReason':            null,
        'viewerCount':          0,
        'thumbnailUrl':         null,
      });

      await _notif.sendLivestreamStartedNotification(streamId: streamId);
      return streamId;
    } catch (_) {
      return null;
    }
  }

  Future<bool> endLivestream(String streamId) async {
    try {
      await _firestore.collection('livestreams').doc(streamId).update({
        'status':    'ENDED',
        'endedAt':   FieldValue.serverTimestamp(),
        'endReason': 'MANUAL',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Currently-live streams, most recent first — used for discovery in the
  /// story row (uses the already-deployed status+startedAt composite index).
  Future<List<LivestreamModel>> getActiveLivestreams() async {
    try {
      final snap = await _firestore
          .collection('livestreams')
          .where('status', isEqualTo: 'LIVE')
          .orderBy('startedAt', descending: true)
          .get();
      return snap.docs.map((d) => LivestreamModel.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Single-document status stream — a viewer tears down when this flips
  /// to "ENDED", regardless of whether the broadcaster's own client is
  /// still connected.
  Stream<String?> observeLivestreamStatus(String streamId) {
    return _firestore.collection('livestreams').doc(streamId).snapshots().map(
          (doc) => doc.data()?['status'] as String?,
        );
  }

  Future<void> sendLiveComment(String streamId, String text) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final userData  = await _getUserData(uid);
      final commentId = _uuid.v4();
      await _firestore
          .collection('livestreams')
          .doc(streamId)
          .collection('comments')
          .doc(commentId)
          .set({
        'id':                    commentId,
        'senderId':              uid,
        'senderUsername':        userData['username'] ?? 'Someone',
        'senderProfileImageUrl': userData['profileImageUrl'],
        'text':                  text,
        'timestamp':             FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<List<LiveCommentModel>> observeLiveComments(String streamId) {
    return _firestore
        .collection('livestreams')
        .doc(streamId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LiveCommentModel.fromMap(d.data(), d.id)).toList());
  }

  /// Joins RTDB presence for a stream and arms onDisconnect() so the node
  /// clears itself if the tab is closed or the network drops — no explicit
  /// "leave" call is required for that case.
  Future<void> joinViewerPresence(String streamId, String uid) async {
    final ref = _rtdb.ref('livestreams/$streamId/viewers/$uid');
    await ref.set(true);
    await ref.onDisconnect().remove();
  }

  Future<void> leaveViewerPresence(String streamId, String uid) async {
    final ref = _rtdb.ref('livestreams/$streamId/viewers/$uid');
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  Stream<int> observeViewerCount(String streamId) {
    return _rtdb.ref('livestreams/$streamId/viewers').onValue.map(
          (event) => event.snapshot.children.length,
        );
  }

  Future<({String token, int uid})> fetchAgoraToken(String channelName, String role) async {
    final result = await _functions.httpsCallable('getAgoraToken').call({
      'channelName': channelName,
      'role':        role,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (token: data['token'] as String, uid: (data['uid'] as num).toInt());
  }

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }
}
