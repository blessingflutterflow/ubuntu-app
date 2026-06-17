import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String  id;
  final String  postId;
  final String  userId;
  final String  username;
  final String  profileImageUrl;
  final String  text;
  final String? imageUrl;
  final String? audioUrl;
  final String? parentCommentId;
  final int     likesCount;
  final List<String> likedBy;
  final DateTime timestamp;
  List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.profileImageUrl = '',
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.parentCommentId,
    this.likesCount = 0,
    this.likedBy = const [],
    required this.timestamp,
    this.replies = const [],
  });

  factory CommentModel.fromMap(Map<String, dynamic> d, String docId) {
    final ts = d['createdAt'] ?? d['timestamp'];
    final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return CommentModel(
      id:              docId,
      postId:          d['postId'] as String? ?? '',
      userId:          d['userId'] as String? ?? '',
      username:        d['username'] as String? ?? 'user',
      profileImageUrl: d['userProfileImage'] as String?
                    ?? d['userProfileImageUrl'] as String? ?? '',
      text:            d['text'] as String? ?? '',
      imageUrl:        d['imageUrl'] as String?,
      audioUrl:        d['audioUrl'] as String?,
      parentCommentId: d['parentCommentId'] as String?,
      likesCount:      (d['likesCount'] as num?)?.toInt() ?? 0,
      likedBy:         List<String>.from(d['likedBy'] as List? ?? []),
      timestamp:       dt,
    );
  }
}
