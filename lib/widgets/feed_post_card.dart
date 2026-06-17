import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import 'story_ring.dart';

class FeedPostCard extends StatefulWidget {
  final PostModel post;
  final PostService postService;
  final VoidCallback? onOpenComments;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenReels;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.postService,
    this.onOpenComments,
    this.onOpenProfile,
    this.onOpenReels,
  });

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> with SingleTickerProviderStateMixin {
  late bool _isLiked;
  late int  _likesCount;
  bool      _showBurst = false;
  late AnimationController _burstCtrl;
  late Animation<double>   _burstScale;

  @override
  void initState() {
    super.initState();
    _isLiked    = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _burstCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _burstScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.25), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0),  weight: 50),
    ]).animate(CurvedAnimation(parent: _burstCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _burstCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    final newLiked = !_isLiked;
    setState(() {
      _isLiked    = newLiked;
      _likesCount += newLiked ? 1 : -1;
    });
    widget.postService.toggleLike(widget.post.id);
  }

  void _doubleTapLike() {
    if (!_isLiked) _toggleLike();
    setState(() => _showBurst = true);
    _burstCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showBurst = false);
      });
    });
  }

  Future<void> _share() async {
    // Same deep link format as the Android app
    final link = 'https://blessingflutterflow.github.io/ubuntu-oasis-share/?post=${widget.post.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          backgroundColor: UbuntuColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: StoryRing(avatarUrl: post.user.profileImageUrl, name: post.user.username, isUnread: false, size: 36),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onOpenProfile,
                    child: Text(post.user.username, style: UbuntuText.username.copyWith(color: UbuntuColors.ink)),
                  ),
                ),
                const Icon(Icons.more_vert, color: UbuntuColors.ink, size: 20),
              ],
            ),
          ),
        ),

        // ── Media ──
        if (post.mediaType == MediaType.IMAGE && post.mediaUrls.isNotEmpty)
          _ImageMedia(
            urls:       post.mediaUrls,
            showBurst:  _showBurst,
            burstScale: _burstScale,
            onDoubleTap: _doubleTapLike,
          )
        else if (post.mediaType == MediaType.VIDEO)
          _VideoThumb(
            thumbUrl: post.videoThumbnailUrl ?? post.videoUrl ?? '',
            onTap:    widget.onOpenReels,
          )
        else if (post.mediaType == MediaType.TEXT && post.caption.isNotEmpty)
          _TextContent(text: post.caption),

        // ── Action bar ──
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _LikeButton(isLiked: _isLiked, onTap: _toggleLike),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: widget.onOpenComments,
                  child: const Icon(Icons.chat_bubble_outline, color: UbuntuColors.ink, size: 25),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _share,
                  child: const Icon(Icons.share, color: UbuntuColors.ink, size: 24),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),

        // ── Likes + caption + timestamp ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('$_likesCount likes', style: UbuntuText.counter.copyWith(color: UbuntuColors.ink)),
        ),
        if (post.caption.isNotEmpty && post.mediaType != MediaType.TEXT)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: UbuntuText.body.copyWith(color: UbuntuColors.ink),
                children: [
                  TextSpan(text: post.user.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: '  '),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),
        if (post.commentsCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: widget.onOpenComments,
              child: Text(
                'View all ${post.commentsCount} comments',
                style: UbuntuText.body.copyWith(color: UbuntuColors.muted),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
          child: Text(
            formatTimestamp(post.timestamp).toUpperCase(),
            style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool     isLiked;
  final VoidCallback onTap;
  const _LikeButton({required this.isLiked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? UbuntuColors.liked : UbuntuColors.ink,
        size: 26,
      ),
    );
  }
}

class _ImageMedia extends StatefulWidget {
  final List<String> urls;
  final bool         showBurst;
  final Animation<double> burstScale;
  final VoidCallback onDoubleTap;
  const _ImageMedia({required this.urls, required this.showBurst, required this.burstScale, required this.onDoubleTap});

  @override
  State<_ImageMedia> createState() => _ImageMediaState();
}

class _ImageMediaState extends State<_ImageMedia> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              itemCount:  urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl:    urls[i],
                fit:         BoxFit.cover,
                width:       double.infinity,
                placeholder: (_, __) => Container(
                  color: UbuntuColors.surface,
                  child: const Center(child: CircularProgressIndicator(color: UbuntuColors.primary, strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: UbuntuColors.surface,
                  child: const Icon(Icons.broken_image, color: UbuntuColors.muted, size: 48),
                ),
              ),
            ),
            // Dot indicators — only show when more than 1 image
            if (urls.length > 1)
              Positioned(
                bottom: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(urls.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width:  _page == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:        _page == i ? UbuntuColors.primary : Colors.white70,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
            // Image count badge (top right) — only when multiple
            if (urls.length > 1)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_page + 1}/${urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            if (widget.showBurst)
              ScaleTransition(
                scale: widget.burstScale,
                child: const Icon(Icons.favorite, color: Colors.white, size: 96),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String   thumbUrl;
  final VoidCallback? onTap;
  const _VideoThumb({required this.thumbUrl, this.onTap});

  bool get _hasThumb => thumbUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base layer: thumbnail or light placeholder (matches Kotlin app)
            _hasThumb
                ? CachedNetworkImage(
                    imageUrl:    thumbUrl,
                    fit:         BoxFit.cover,
                    width:       double.infinity,
                    placeholder: (_, __) => _lightPlaceholder(),
                    errorWidget: (_, __, ___) => _lightPlaceholder(),
                  )
                : _lightPlaceholder(),

            // Play button
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            ),

            // Reel badge
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color:        Colors.black.withOpacity(0.55),
                ),
                child: const Text('Reel', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lightPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: UbuntuColors.canvas,
      child: const Center(
        child: Icon(Icons.videocam, color: UbuntuColors.muted, size: 48),
      ),
    );
  }
}

class _TextContent extends StatelessWidget {
  final String text;
  const _TextContent({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      color:   UbuntuColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Text(
        text,
        style:     UbuntuText.body.copyWith(fontSize: 18, color: UbuntuColors.ink),
        textAlign: TextAlign.center,
      ),
    );
  }
}
