import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/post_service.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feed_post_card.dart';
import '../../widgets/story_ring.dart';
import '../../widgets/avatar.dart';
import '../reels/reels_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int  _tab            = 0;
  String _reelsStartId = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: IndexedStack(
        index: _tab == 1 ? 1 : 0,
        children: [
          _HomeTab(
            onOpenReels: (postId) => setState(() { _reelsStartId = postId; _tab = 1; }),
          ),
          ReelsScreen(startPostId: _reelsStartId),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selected: _tab,
        onSelect: (i) {
          if (i == 2) {
            showModalBottomSheet(
              context: context,
              backgroundColor: UbuntuColors.canvas,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: UbuntuColors.divider, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: UbuntuColors.primary,
                          child: Icon(Icons.grid_on, color: Colors.white)),
                        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Share photos or videos to your feed'),
                        onTap: () { Navigator.pop(context); context.push('/create-post'); },
                      ),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: UbuntuColors.accent,
                          child: Icon(Icons.auto_stories, color: Colors.white)),
                        title: const Text('New Story', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Share a moment that disappears in 24h'),
                        onTap: () { Navigator.pop(context); context.push('/create-story'); },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
            return;
          }
          if (i == 3) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            context.push('/profile/$uid');
            return;
          }
          if (i == 0 && _tab == 0) return;
          setState(() { _tab = i; });
        },
      ),
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final void Function(String postId) onOpenReels;
  const _HomeTab({required this.onOpenReels});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _postService  = PostService();
  final _userService  = UserService();
  final _notifService = NotificationService();

  List<PostModel>  _posts      = [];
  List<UserModel>  _storyUsers = [];
  UserModel?       _me;
  bool             _loading    = true;
  bool             _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final results = await Future.wait([
      _postService.getPosts(),
      _userService.getCurrentUser(),
      _userService.getStoriesUsers(),
    ]);

    if (mounted) {
      setState(() {
        _posts      = results[0] as List<PostModel>;
        _me         = results[1] as UserModel?;
        _storyUsers = results[2] as List<UserModel>;
        _loading    = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: Column(
        children: [
          _FeedTopBar(notifService: _notifService),
          const Divider(height: 0),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: UbuntuColors.primary))
                : RefreshIndicator(
                    color:      UbuntuColors.primary,
                    onRefresh:  _refresh,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _StoriesRow(me: _me, others: _storyUsers)),
                        const SliverToBoxAdapter(child: Divider(height: 0)),
                        if (_posts.isEmpty)
                          const SliverFillRemaining(
                            child: Center(
                              child: Text('No posts yet', style: UbuntuText.body),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final post = _posts[i];
                                return Column(
                                  children: [
                                    FeedPostCard(
                                      post:        post,
                                      postService: _postService,
                                      onOpenProfile: () => context.push('/profile/${post.user.id}'),
                                      onOpenComments: () => context.push('/comments/${post.id}', extra: post.user.username),
                                      onOpenReels: () => widget.onOpenReels(post.id),
                                    ),
                                    const Divider(height: 0),
                                  ],
                                );
                              },
                              childCount: _posts.length,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _FeedTopBar extends StatelessWidget {
  final NotificationService notifService;
  const _FeedTopBar({required this.notifService});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [UbuntuColors.primary, UbuntuColors.accent],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ).createShader(b),
                child: const Text('ubuntuness', style: UbuntuText.wordmark, ),
              ),
              const Spacer(),
              StreamBuilder<int>(
                stream: notifService.unreadCountStream(),
                builder: (_, snap) {
                  final count = snap.data ?? 0;
                  return GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, color: UbuntuColors.ink, size: 26),
                        if (count > 0)
                          Positioned(
                            top: -2, right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: const BoxDecoration(color: UbuntuColors.badge, shape: BoxShape.circle),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style:     const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stories row ───────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  final UserModel?       me;
  final List<UserModel>  others;
  const _StoriesRow({this.me, required this.others});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (me != null) _OwnStoryItem(user: me!),
          ...others.map((u) => _StoryItem(user: u)),
        ],
      ),
    );
  }
}

class _OwnStoryItem extends StatelessWidget {
  final UserModel user;
  const _OwnStoryItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Tapping the avatar/ring views the story (or creates if none)
                GestureDetector(
                  onTap: () => user.hasActiveStory
                      ? context.push('/story/${user.id}', extra: true)
                      : context.push('/create-story'),
                  child: user.hasActiveStory
                      ? StoryRing(avatarUrl: user.profileImageUrl, name: user.username, isUnread: true, size: 80)
                      : UbuntuAvatar(url: user.profileImageUrl, name: user.username, size: 80, borderWidth: 1),
                ),
                // The + badge always opens create-story
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => context.push('/create-story'),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: UbuntuColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: UbuntuColors.canvas, width: 2),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text('Your Story', style: UbuntuText.storyLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final UserModel user;
  const _StoryItem({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/story/${user.id}', extra: false),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoryRing(avatarUrl: user.profileImageUrl, name: user.username, isUnread: user.hasActiveStory, size: 80),
            const SizedBox(height: 5),
            SizedBox(
              width: 80,
              child: Text(
                user.username,
                style:     UbuntuText.storyLabel,
                maxLines:  1,
                overflow:  TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;

  const _BottomNav({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 0),
        NavigationBar(
          backgroundColor:    UbuntuColors.canvas,
          elevation:          0,
          shadowColor:        Colors.transparent,
          indicatorColor:     Colors.transparent,
          selectedIndex:      selected.clamp(0, 3),
          onDestinationSelected: onSelect,
          destinations: [
            NavigationDestination(
              icon:         Icon(Icons.home_outlined,   color: selected == 0 ? UbuntuColors.ink : UbuntuColors.muted),
              selectedIcon: const Icon(Icons.home,      color: UbuntuColors.ink),
              label: '',
            ),
            NavigationDestination(
              icon:         Icon(Icons.play_circle_outline, color: selected == 1 ? UbuntuColors.ink : UbuntuColors.muted),
              selectedIcon: const Icon(Icons.play_circle,   color: UbuntuColors.ink),
              label: '',
            ),
            const NavigationDestination(
              icon: Icon(Icons.add_circle_outline, color: UbuntuColors.primary, size: 28),
              label: '',
            ),
            NavigationDestination(
              icon: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                builder: (_, snap) {
                  final url = snap.data?.get('profileImageUrl') as String?;
                  final name = snap.data?.get('username') as String? ?? '';
                  return UbuntuAvatar(
                    url:         url,
                    name:        name,
                    size:        26,
                    borderWidth: selected == 3 ? 2 : 0,
                    borderColor: UbuntuColors.ink,
                  );
                },
              ),
              label: '',
            ),
          ],
        ),
      ],
    );
  }
}
