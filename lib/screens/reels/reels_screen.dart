import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class ReelsScreen extends StatefulWidget {
  final String startPostId;
  const ReelsScreen({super.key, this.startPostId = ''});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final _postService = PostService();
  List<PostModel> _reels   = [];
  bool            _loading = true;
  late PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await _postService.getPosts(limit: 30);
    final reels = posts.where((p) => p.mediaType == MediaType.VIDEO).toList();
    final startIdx = widget.startPostId.isNotEmpty
        ? reels.indexWhere((p) => p.id == widget.startPostId).clamp(0, (reels.length - 1).clamp(0, 9999))
        : 0;
    _pageCtrl = PageController(initialPage: startIdx);
    if (mounted) setState(() { _reels = reels; _loading = false; _currentPage = startIdx; });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: UbuntuColors.primary)),
      );
    }
    if (_reels.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('No reels yet', style: TextStyle(color: Colors.white))),
      );
    }

    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      onPageChanged: (i) => setState(() => _currentPage = i),
      itemCount: _reels.length,
      itemBuilder: (_, i) => _ReelItem(
        post:     _reels[i],
        isActive: _currentPage == i,
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final PostModel post;
  final bool      isActive;
  const _ReelItem({required this.post, required this.isActive});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _isMuted  = true;
  bool _isLiked  = false;
  late int _likes;
  final _postService = PostService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likes   = widget.post.likesCount;
    final url = widget.post.videoUrl ?? '';
    if (url.isNotEmpty) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _ctrl!.setLooping(true);
            _ctrl!.setVolume(0);
            if (widget.isActive) _ctrl!.play();
          }
        });
    }
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        _ctrl?.play();
      } else {
        _ctrl?.pause();
        _ctrl?.seekTo(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _ctrl?.setVolume(_isMuted ? 0 : 1);
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });
    _postService.toggleLike(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video / thumbnail
        Container(color: Colors.black),
        if (_ctrl != null && _ctrl!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width:  _ctrl!.value.size.width,
              height: _ctrl!.value.size.height,
              child:  VideoPlayer(_ctrl!),
            ),
          )
        else if (post.videoThumbnailUrl != null && post.videoThumbnailUrl!.isNotEmpty)
          CachedNetworkImage(imageUrl: post.videoThumbnailUrl!, fit: BoxFit.cover),

        // Bottom-left: user + caption
        Positioned(
          left: 14, right: 80, bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => context.push('/profile/${post.user.id}'),
                child: Row(
                  children: [
                    UbuntuAvatar(url: post.user.profileImageUrl, name: post.user.username, size: 32, borderWidth: 1, borderColor: Colors.white),
                    const SizedBox(width: 8),
                    Text('@${post.user.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ),
              if (post.caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(post.caption, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),

        // Right-side actions
        Positioned(
          right: 14, bottom: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionBtn(
                icon:  _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? UbuntuColors.liked : Colors.white,
                label: formatCount(_likes),
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),
              _ActionBtn(
                icon:  Icons.chat_bubble_outline,
                color: Colors.white,
                label: formatCount(post.commentsCount),
                onTap: () => context.push('/comments/${post.id}', extra: post.user.username),
              ),
              const SizedBox(height: 20),
              _ActionBtn(icon: Icons.send_outlined, color: Colors.white, label: '', onTap: () {}),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                  child: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
