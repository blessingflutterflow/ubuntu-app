import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feed_post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _postService = PostService();
  PostModel? _post;
  bool       _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await _postService.getPostById(widget.postId);
    if (mounted) setState(() { _post = post; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      appBar: AppBar(
        backgroundColor: UbuntuColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
          onPressed: () => context.pop(),
        ),
        title: const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UbuntuColors.primary))
          : _post == null
              ? const Center(child: Text('Post not found', style: UbuntuText.body))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const Divider(height: 0),
                      FeedPostCard(
                        post:        _post!,
                        postService: _postService,
                        onOpenProfile:  () => context.push('/profile/${_post!.user.id}'),
                        onOpenComments: () => context.push('/comments/${_post!.id}', extra: _post!.user.username),
                        onOpenReels:    () => context.push('/post/${_post!.id}'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
