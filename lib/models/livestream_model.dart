import 'package:cloud_firestore/cloud_firestore.dart';

/// A livestream broadcast. `status` stays a plain string ("LIVE"/"ENDED")
/// rather than a Dart enum, matching the posts.status convention on both
/// clients — same Firestore documents either app can read.
class LivestreamModel {
  final String id;
  final String broadcasterId;
  final String broadcasterUsername;
  final String? broadcasterAvatarUrl;
  final String channelName;
  final String title;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final int viewerCount;
  final String? thumbnailUrl;

  const LivestreamModel({
    required this.id,
    required this.broadcasterId,
    required this.broadcasterUsername,
    this.broadcasterAvatarUrl,
    required this.channelName,
    this.title = '',
    this.status = 'LIVE',
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.viewerCount = 0,
    this.thumbnailUrl,
  });

  factory LivestreamModel.fromMap(Map<String, dynamic> data, String docId) {
    DateTime? toDate(dynamic v) => v is Timestamp ? v.toDate() : null;
    return LivestreamModel(
      id:                   data['id'] as String? ?? docId,
      broadcasterId:        data['broadcasterId'] as String? ?? '',
      broadcasterUsername:  data['broadcasterUsername'] as String? ?? 'Someone',
      broadcasterAvatarUrl: data['broadcasterAvatarUrl'] as String?,
      channelName:          data['channelName'] as String? ?? docId,
      title:                data['title'] as String? ?? '',
      status:               data['status'] as String? ?? 'LIVE',
      startedAt:            toDate(data['startedAt']),
      endedAt:              toDate(data['endedAt']),
      endReason:            data['endReason'] as String?,
      viewerCount:          (data['viewerCount'] as num?)?.toInt() ?? 0,
      thumbnailUrl:         data['thumbnailUrl'] as String?,
    );
  }
}

class LiveCommentModel {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderProfileImageUrl;
  final String text;
  final DateTime? timestamp;

  const LiveCommentModel({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderProfileImageUrl,
    required this.text,
    this.timestamp,
  });

  factory LiveCommentModel.fromMap(Map<String, dynamic> data, String docId) {
    final ts = data['timestamp'];
    return LiveCommentModel(
      id:                    data['id'] as String? ?? docId,
      senderId:              data['senderId'] as String? ?? '',
      senderUsername:        data['senderUsername'] as String? ?? 'Someone',
      senderProfileImageUrl: data['senderProfileImageUrl'] as String?,
      text:                  data['text'] as String? ?? '',
      timestamp:             ts is Timestamp ? ts.toDate() : null,
    );
  }
}
