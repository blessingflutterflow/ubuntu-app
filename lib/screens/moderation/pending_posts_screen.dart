import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';

class PendingPostsScreen extends StatefulWidget {
  const PendingPostsScreen({super.key});

  @override
  State<PendingPostsScreen> createState() => _PendingPostsScreenState();
}

class _PendingPostsScreenState extends State<PendingPostsScreen> {
  final _moderationService = ModerationService();

  bool?           _isAdmin;
  List<PostModel> _pending = [];
  bool            _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isAdmin = await _moderationService.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = isAdmin);
    if (isAdmin) await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    final posts = await _moderationService.getPendingPosts();
    if (mounted) setState(() => _pending = posts);
  }

  Future<void> _approve(PostModel post) async {
    await _moderationService.approvePost(post.id, post.user.id);
    await _refresh();
  }

  Future<void> _reject(PostModel post) async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.trim().isEmpty) return;
    await _moderationService.rejectPost(post.id, post.user.id, reason.trim());
    await _refresh();
  }

  Future<String?> _showRejectDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject post', style: TextStyle(fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tell the author why this post was rejected.', style: TextStyle(color: UbuntuColors.muted, fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Reason...',
                  filled: true,
                  fillColor: UbuntuColors.input,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: UbuntuColors.muted)),
            ),
            TextButton(
              onPressed: controller.text.trim().isEmpty ? null : () => Navigator.of(context).pop(controller.text),
              child: Text(
                'Confirm Reject',
                style: TextStyle(color: controller.text.trim().isEmpty ? UbuntuColors.muted : UbuntuColors.liked),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Text('Pending Approvals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 0),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading || _isAdmin == null) {
      return const Center(child: CircularProgressIndicator(color: UbuntuColors.primary));
    }
    if (_isAdmin == false) {
      return const Center(
        child: Text("You don't have access to this page.", style: TextStyle(color: UbuntuColors.muted)),
      );
    }
    if (_pending.isEmpty) {
      return const Center(child: Text('No posts awaiting review', style: TextStyle(color: UbuntuColors.muted)));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _pending.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (_, i) {
        final post = _pending[i];
        final thumb = post.mediaUrls.firstOrNull ?? post.videoThumbnailUrl;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UbuntuAvatar(url: post.user.profileImageUrl, name: post.user.username, size: 32),
                  const SizedBox(width: 8),
                  Text(post.user.username, style: const TextStyle(fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
                ],
              ),
              const SizedBox(height: 10),
              if (thumb != null && thumb.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(aspectRatio: 4 / 3, child: Image.network(thumb, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 8),
              ],
              if (post.caption.isNotEmpty) ...[
                Text(post.caption, style: const TextStyle(color: UbuntuColors.ink), maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _approve(post),
                    style: ElevatedButton.styleFrom(backgroundColor: UbuntuColors.primary, foregroundColor: Colors.white),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _reject(post),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
