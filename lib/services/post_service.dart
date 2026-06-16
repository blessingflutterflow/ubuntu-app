import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import 'notification_service.dart';

class PostService {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;
  final _storage   = FirebaseStorage.instance;
  final _notif     = NotificationService();
  final _uuid      = const Uuid();

  String? get _uid => _auth.currentUser?.uid;

  Future<List<PostModel>> getPosts({int limit = 20, DocumentSnapshot? lastDoc}) async {
    var query = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);

    final snap = await query.get();
    final posts = <PostModel>[];
    for (final doc in snap.docs) {
      try {
        final post = PostModel.fromMap(doc.data(), doc.id);
        post.isLiked = await hasLiked(doc.id);
        posts.add(post);
      } catch (_) {}
    }
    return posts;
  }

  Future<PostModel?> getPostById(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    final post = PostModel.fromMap(doc.data()!, doc.id);
    post.isLiked = await hasLiked(postId);
    return post;
  }

  Stream<DocumentSnapshot> listenToPost(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots();
  }

  Future<bool> hasLiked(String postId) async {
    if (_uid == null) return false;
    final doc = await _firestore.collection('posts').doc(postId).collection('likes').doc(_uid).get();
    return doc.exists;
  }

  Future<bool> toggleLike(String postId) async {
    if (_uid == null) return false;
    final postRef  = _firestore.collection('posts').doc(postId);
    final likeRef  = postRef.collection('likes').doc(_uid);
    String? ownerId;

    bool newState = false;
    await _firestore.runTransaction((tx) async {
      final postSnap = await tx.get(postRef);
      final likeSnap = await tx.get(likeRef);
      ownerId = postSnap.data()?['userId'] as String?;
      final count = (postSnap.data()?['likesCount'] as num?)?.toInt() ?? 0;

      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likesCount': (count - 1).clamp(0, 999999)});
        newState = false;
      } else {
        tx.set(likeRef, {'userId': _uid, 'timestamp': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likesCount': count + 1});
        newState = true;
      }
    });

    if (newState && ownerId != null && ownerId != _uid) {
      _notif.sendLikeNotification(postId: postId, postOwnerId: ownerId!);
    }
    return newState;
  }

  Future<String> createTextPost(String caption) async {
    final uid   = _uid!;
    final userData = await _getUserData(uid);
    final postId   = _uuid.v4();
    await _firestore.collection('posts').doc(postId).set({
      'id':                 postId,
      'userId':             uid,
      'userDisplayName':    userData['displayName'],
      'userUsername':       userData['username'],
      'userProfileImageUrl': userData['profileImageUrl'],
      'caption':            caption,
      'textContent':        caption,
      'mediaType':          'TEXT',
      'mediaUrls':          [],
      'videoUrl':           null,
      'likesCount':         0,
      'commentsCount':      0,
      'timestamp':          FieldValue.serverTimestamp(),
      'isLiked':            false,
      'isBookmarked':       false,
    });
    _notif.sendNewPostNotification(postId: postId, postOwnerId: uid);
    return postId;
  }

  Future<String> createImagePost(String caption, List<XFile> images) async {
    final uid      = _uid!;
    final userData = await _getUserData(uid);
    final urls     = await Future.wait(images.map((f) => _uploadFile(f, 'posts/images')));
    final postId   = _uuid.v4();
    await _firestore.collection('posts').doc(postId).set({
      'id':                 postId,
      'userId':             uid,
      'userDisplayName':    userData['displayName'],
      'userUsername':       userData['username'],
      'userProfileImageUrl': userData['profileImageUrl'],
      'caption':            caption,
      'textContent':        null,
      'mediaType':          'IMAGE',
      'mediaUrls':          urls,
      'videoUrl':           null,
      'likesCount':         0,
      'commentsCount':      0,
      'timestamp':          FieldValue.serverTimestamp(),
      'isLiked':            false,
      'isBookmarked':       false,
    });
    _notif.sendNewPostNotification(postId: postId, postOwnerId: uid);
    return postId;
  }

  Future<String> createVideoPost(String caption, XFile video, {XFile? thumbnail}) async {
    final uid        = _uid!;
    final userData   = await _getUserData(uid);
    final videoUrl   = await _uploadFile(video, 'posts/videos');
    final thumbUrl   = thumbnail != null ? await _uploadFile(thumbnail, 'posts/videos/thumbnails') : '';
    final postId     = _uuid.v4();
    await _firestore.collection('posts').doc(postId).set({
      'id':                  postId,
      'userId':              uid,
      'userDisplayName':     userData['displayName'],
      'userUsername':        userData['username'],
      'userProfileImageUrl': userData['profileImageUrl'],
      'caption':             caption,
      'textContent':         null,
      'mediaType':           'VIDEO',
      'mediaUrls':           [],
      'videoUrl':            videoUrl,
      'videoThumbnailUrl':   thumbUrl,
      'likesCount':          0,
      'commentsCount':       0,
      'timestamp':           FieldValue.serverTimestamp(),
      'isLiked':             false,
      'isBookmarked':        false,
    });
    _notif.sendNewPostNotification(postId: postId, postOwnerId: uid);
    return postId;
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final snap = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();
    final posts = <PostModel>[];
    for (final doc in snap.docs) {
      try { posts.add(PostModel.fromMap(doc.data(), doc.id)); } catch (_) {}
    }
    return posts;
  }

  Future<String> _uploadFile(XFile file, String path) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final filename = '${_uuid.v4()}.$ext';
    final ref = _storage.ref().child('$path/$filename');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  Future<Map<String, dynamic>> _getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }
}
