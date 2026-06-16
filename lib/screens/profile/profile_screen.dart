import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/user_service.dart';
import '../../services/post_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService  = UserService();
  final _postService  = PostService();
  final _notifService = NotificationService();

  UserModel?       _profile;
  List<PostModel>  _posts       = [];
  bool             _loading     = true;
  bool             _isFollowing = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool   get _isOwn      => widget.userId == _currentUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _userService.getUser(widget.userId),
      _postService.getUserPosts(widget.userId),
      if (!_isOwn) _userService.isFollowing(widget.userId),
    ]);
    if (mounted) {
      setState(() {
        _profile     = results[0] as UserModel?;
        _posts       = results[1] as List<PostModel>;
        _isFollowing = results.length > 2 ? results[2] as bool : false;
        _loading     = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !_isFollowing);
    if (wasFollowing) {
      await _userService.unfollow(widget.userId);
    } else {
      await _userService.follow(widget.userId);
      _notifService.sendFollowNotification(followedUserId: widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: Column(
        children: [
          _TopBar(
            username: _profile?.username ?? '',
            isOwn:    _isOwn,
            onBack:   () => context.pop(),
            onEdit:   () => context.push('/edit-profile'),
          ),
          const Divider(height: 0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: UbuntuColors.primary))
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ProfileHeader(
                          profile:     _profile,
                          isOwn:       _isOwn,
                          isFollowing: _isFollowing,
                          onFollow:    _toggleFollow,
                          onEdit:      () => context.push('/edit-profile'),
                        ),
                      ),
                      if (_posts.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: Text('No posts yet', style: UbuntuText.body)),
                        )
                      else
                        SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _PostThumb(
                              post:    _posts[i],
                              onTap: () => context.push('/post/${_posts[i].id}'),
                            ),
                            childCount: _posts.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, mainAxisSpacing: 1, crossAxisSpacing: 1,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String     username;
  final bool       isOwn;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  const _TopBar({required this.username, required this.isOwn, required this.onBack, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  username.isEmpty ? 'Profile' : username,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel?   profile;
  final bool         isOwn;
  final bool         isFollowing;
  final VoidCallback onFollow;
  final VoidCallback onEdit;
  const _ProfileHeader({this.profile, required this.isOwn, required this.isFollowing, required this.onFollow, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          UbuntuAvatar(url: p?.profileImageUrl, name: p?.displayName ?? p?.username, size: 90, borderWidth: 1),
          const SizedBox(height: 12),
          Text(
            p?.displayName.isNotEmpty == true ? p!.displayName : (p?.username ?? ''),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: UbuntuColors.ink),
          ),
          if (p?.username.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text('@${p!.username}', style: UbuntuText.storyLabel.copyWith(color: UbuntuColors.muted)),
          ],
          if (p?.bio.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              p!.bio,
              style:     UbuntuText.body.copyWith(color: UbuntuColors.ink),
              textAlign: TextAlign.center,
              maxLines:  3,
              overflow:  TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(value: formatCount(p?.postsCount ?? 0),     label: 'Posts'),
              _Stat(value: formatCount(p?.followersCount ?? 0), label: 'Followers'),
              _Stat(value: formatCount(p?.followingCount ?? 0), label: 'Following'),
            ],
          ),
          const SizedBox(height: 16),
          // Follow / Edit button
          if (isOwn)
            _OutlineBtn(label: 'Edit Profile', onTap: onEdit)
          else
            _FilledBtn(
              label:   isFollowing ? 'Following' : 'Follow',
              filled:  !isFollowing,
              onTap:   onFollow,
            ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.grid_on, color: UbuntuColors.ink, size: 22)],
          ),
          const SizedBox(height: 4),
          const Divider(thickness: 1.5, color: UbuntuColors.ink),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: UbuntuColors.ink)),
        const SizedBox(height: 2),
        Text(label, style: UbuntuText.storyLabel.copyWith(color: UbuntuColors.muted)),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String     label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 38,
        decoration: BoxDecoration(
          border:       Border.all(color: UbuntuColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: UbuntuColors.ink))),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String     label;
  final bool       filled;
  final VoidCallback onTap;
  const _FilledBtn({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  double.infinity,
        height: 38,
        decoration: BoxDecoration(
          color:        filled ? UbuntuColors.primary : UbuntuColors.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: filled ? Colors.white : UbuntuColors.ink),
          ),
        ),
      ),
    );
  }
}

class _PostThumb extends StatelessWidget {
  final PostModel    post;
  final VoidCallback onTap;
  const _PostThumb({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = post.mediaUrls.firstOrNull ?? post.videoThumbnailUrl ?? post.videoUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url.isNotEmpty
              ? Image.network(url, fit: BoxFit.cover)
              : Container(color: UbuntuColors.input),
          if (post.mediaType == MediaType.VIDEO)
            const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 28)),
        ],
      ),
    );
  }
}
