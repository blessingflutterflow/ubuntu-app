class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final String bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isVerified;
  final bool hasActiveStory;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    this.bio = '',
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isVerified = false,
    this.hasActiveStory = false,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id:              id,
      username:        data['username'] as String? ?? 'user',
      displayName:     data['displayName'] as String? ?? 'User',
      profileImageUrl: data['profileImageUrl'] as String?,
      bio:             data['bio'] as String? ?? '',
      postsCount:      (data['postsCount'] as num?)?.toInt() ?? 0,
      followersCount:  (data['followersCount'] as num?)?.toInt() ?? 0,
      followingCount:  (data['followingCount'] as num?)?.toInt() ?? 0,
      isVerified:      data['isVerified'] as bool? ?? false,
      hasActiveStory:  data['hasActiveStory'] as bool? ?? false,
      fcmToken:        data['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':             id,
    'username':        username,
    'displayName':     displayName,
    'profileImageUrl': profileImageUrl,
    'bio':             bio,
    'postsCount':      postsCount,
    'followersCount':  followersCount,
    'followingCount':  followingCount,
    'isVerified':      isVerified,
    'hasActiveStory':  hasActiveStory,
  };

  UserModel copyWith({
    String? username,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    bool? isVerified,
    bool? hasActiveStory,
  }) => UserModel(
    id:              id,
    username:        username        ?? this.username,
    displayName:     displayName     ?? this.displayName,
    profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    bio:             bio             ?? this.bio,
    postsCount:      postsCount      ?? this.postsCount,
    followersCount:  followersCount  ?? this.followersCount,
    followingCount:  followingCount  ?? this.followingCount,
    isVerified:      isVerified      ?? this.isVerified,
    hasActiveStory:  hasActiveStory  ?? this.hasActiveStory,
  );
}
