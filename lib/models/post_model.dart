import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { TEXT, IMAGE, VIDEO }

class PostUser {
  final String id;
  final String username;
  final String displayName;
  final String? profileImageUrl;

  const PostUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
  });
}

class PostModel {
  final String id;
  final PostUser user;
  final String caption;
  final List<String> mediaUrls;
  final MediaType mediaType;
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final String? textContent;
  final int likesCount;
  final int commentsCount;
  final DateTime timestamp;
  bool isLiked;
  bool isBookmarked;

  PostModel({
    required this.id,
    required this.user,
    required this.caption,
    required this.mediaUrls,
    required this.mediaType,
    this.videoUrl,
    this.videoThumbnailUrl,
    this.textContent,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.timestamp,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> data, String docId) {
    final mediaTypeStr = data['mediaType'] as String? ?? 'TEXT';
    final mediaType = MediaType.values.firstWhere(
      (e) => e.name == mediaTypeStr,
      orElse: () => MediaType.TEXT,
    );

    final ts = data['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else {
      timestamp = DateTime.now();
    }

    return PostModel(
      id:               docId,
      user: PostUser(
        id:              data['userId'] as String? ?? '',
        username:        data['userUsername'] as String? ?? 'user',
        displayName:     data['userDisplayName'] as String? ?? 'User',
        profileImageUrl: data['userProfileImageUrl'] as String?,
      ),
      caption:          data['caption'] as String? ?? '',
      mediaUrls:        List<String>.from(data['mediaUrls'] as List? ?? []),
      mediaType:        mediaType,
      videoUrl:         data['videoUrl'] as String?,
      videoThumbnailUrl: data['videoThumbnailUrl'] as String?,
      textContent:      data['textContent'] as String?,
      likesCount:       (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount:    (data['commentsCount'] as num?)?.toInt() ?? 0,
      timestamp:        timestamp,
      isLiked:          data['isLiked'] as bool? ?? false,
      isBookmarked:     data['isBookmarked'] as bool? ?? false,
    );
  }

  PostModel copyWith({int? likesCount, int? commentsCount, bool? isLiked, bool? isBookmarked}) =>
    PostModel(
      id:               id,
      user:             user,
      caption:          caption,
      mediaUrls:        mediaUrls,
      mediaType:        mediaType,
      videoUrl:         videoUrl,
      videoThumbnailUrl: videoThumbnailUrl,
      textContent:      textContent,
      likesCount:       likesCount    ?? this.likesCount,
      commentsCount:    commentsCount ?? this.commentsCount,
      timestamp:        timestamp,
      isLiked:          isLiked       ?? this.isLiked,
      isBookmarked:     isBookmarked  ?? this.isBookmarked,
    );
}
