import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type;
  final String senderId;
  final String senderUsername;
  final String? senderProfileImageUrl;
  final String receiverId;
  final String? postId;
  final String? commentId;
  final String message;
  final String? postThumbnailUrl;
  final bool isRead;
  final DateTime timestamp;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderUsername,
    this.senderProfileImageUrl,
    required this.receiverId,
    this.postId,
    this.commentId,
    required this.message,
    this.postThumbnailUrl,
    required this.isRead,
    required this.timestamp,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> data, String docId) {
    final ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else {
      timestamp = DateTime.now();
    }

    return NotificationModel(
      id:                    docId,
      type:                  data['type'] as String? ?? '',
      senderId:              data['senderId'] as String? ?? '',
      senderUsername:        data['senderUsername'] as String? ?? 'Someone',
      senderProfileImageUrl: data['senderProfileImageUrl'] as String?,
      receiverId:            data['receiverId'] as String? ?? '',
      postId:                data['postId'] as String?,
      commentId:             data['commentId'] as String?,
      message:               data['message'] as String? ?? '',
      postThumbnailUrl:      data['postThumbnailUrl'] as String?,
      isRead:                data['isRead'] as bool? ?? false,
      timestamp:             timestamp,
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id:                    id,
    type:                  type,
    senderId:              senderId,
    senderUsername:        senderUsername,
    senderProfileImageUrl: senderProfileImageUrl,
    receiverId:            receiverId,
    postId:                postId,
    commentId:             commentId,
    message:               message,
    postThumbnailUrl:      postThumbnailUrl,
    isRead:                isRead ?? this.isRead,
    timestamp:             timestamp,
  );
}
