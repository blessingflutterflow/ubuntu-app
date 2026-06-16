import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String? profileImageUrl;
  final String text;
  final DateTime timestamp;
  final int likesCount;
  bool isLiked;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.profileImageUrl,
    required this.text,
    required this.timestamp,
    this.likesCount = 0,
    this.isLiked = false,
  });

  factory CommentModel.fromMap(Map<String, dynamic> data, String docId) {
    final ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else {
      timestamp = DateTime.now();
    }
    return CommentModel(
      id:              docId,
      postId:          data['postId'] as String? ?? '',
      userId:          data['userId'] as String? ?? '',
      username:        data['username'] as String? ?? 'user',
      profileImageUrl: data['userProfileImageUrl'] as String?,
      text:            data['text'] as String? ?? '',
      timestamp:       timestamp,
      likesCount:      (data['likesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
