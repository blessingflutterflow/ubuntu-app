import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../../models/comment_model.dart';
import '../../services/comment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _svc        = CommentService();
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  bool   _submitting        = false;
  String _postOwnerId       = '';
  String? _replyToCommentId;
  String? _replyToUserId;
  String? _replyToUsername;

  // Image attach
  Uint8List? _imageBytes;
  String?    _imageFileName;

  // Expand state for replies
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadPostOwner();
  }

  Future<void> _loadPostOwner() async {
    final doc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
    if (mounted) setState(() => _postOwnerId = doc.data()?['userId'] as String? ?? '');
  }

  void _setReply(CommentModel c) {
    setState(() {
      _replyToCommentId = c.id;
      _replyToUserId    = c.userId;
      _replyToUsername  = c.username;
    });
    _textCtrl.text = '@${c.username} ';
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserId    = null;
      _replyToUsername  = null;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _imageBytes    = bytes;
      _imageFileName = xfile.name;
    });
  }

  void _removeImage() => setState(() { _imageBytes = null; _imageFileName = null; });

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return null;
    final ref = FirebaseStorage.instance.ref('comments/${DateTime.now().millisecondsSinceEpoch}_${_imageFileName ?? 'img.jpg'}');
    await ref.putData(_imageBytes!);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _imageBytes == null) return;
    setState(() => _submitting = true);
    try {
      final imageUrl = await _uploadImage();
      await _svc.addComment(
        postId:              widget.postId,
        text:                text,
        postOwnerId:         _postOwnerId,
        imageUrl:            imageUrl,
        parentCommentId:     _replyToCommentId,
        parentCommentUserId: _replyToUserId,
      );
      _textCtrl.clear();
      _removeImage();
      _clearReply();
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<CommentModel> _buildTree(List<CommentModel> flat) {
    final main    = flat.where((c) => c.parentCommentId == null).toList();
    final replies = flat.where((c) => c.parentCommentId != null).toList();
    for (final m in main) {
      m.replies = replies.where((r) => r.parentCommentId == m.id).toList();
    }
    return main;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      appBar: AppBar(
        backgroundColor: UbuntuColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
          onPressed: () => context.pop(),
        ),
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('comments')
              .where('postId', isEqualTo: widget.postId).snapshots(),
          builder: (_, snap) {
            final count = snap.data?.docs.length ?? 0;
            return Text('Comments${count > 0 ? ' ($count)' : ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink));
          },
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _svc.commentsStream(widget.postId),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: UbuntuColors.primary));
                final tree = _buildTree(snap.data!);
                if (tree.isEmpty) {
                  return const Center(child: Text('No comments yet. Be the first!', style: UbuntuText.body));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: tree.length,
                  itemBuilder: (_, i) => _CommentTile(
                    comment:    tree[i],
                    currentUid: uid,
                    expanded:   _expandedIds.contains(tree[i].id),
                    onToggleExpand: (id) => setState(() {
                      _expandedIds.contains(id) ? _expandedIds.remove(id) : _expandedIds.add(id);
                    }),
                    onReply: _setReply,
                    onLike:  (c) => _svc.toggleLike(c.id, c.likedBy),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0),
          // Reply banner
          if (_replyToUsername != null)
            Container(
              color: UbuntuColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('Replying to @$_replyToUsername',
                    style: UbuntuText.body.copyWith(color: UbuntuColors.muted, fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { _clearReply(); _textCtrl.clear(); },
                    child: const Icon(Icons.close, size: 16, color: UbuntuColors.muted),
                  ),
                ],
              ),
            ),
          // Image preview
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_imageBytes!, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Input bar
          _InputBar(
            ctrl:        _textCtrl,
            focusNode:   _focusNode,
            submitting:  _submitting,
            isReply:     _replyToCommentId != null,
            onSubmit:    _submit,
            onPickImage: _pickImage,
            uid:         uid,
          ),
        ],
      ),
    );
  }
}

// ── Comment tile with replies ─────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String       currentUid;
  final bool         expanded;
  final void Function(String id)                onToggleExpand;
  final void Function(CommentModel c)           onReply;
  final void Function(CommentModel c)           onLike;

  const _CommentTile({
    required this.comment,
    required this.currentUid,
    required this.expanded,
    required this.onToggleExpand,
    required this.onReply,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentRow(
          comment:    comment,
          currentUid: currentUid,
          isReply:    false,
          onReply:    () => onReply(comment),
          onLike:     () => onLike(comment),
        ),
        // Replies toggle
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 58, bottom: 4),
            child: GestureDetector(
              onTap: () => onToggleExpand(comment.id),
              child: Text(
                expanded
                    ? '▲  Hide ${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'}'
                    : '▼  View ${comment.replies.length} ${comment.replies.length == 1 ? 'reply' : 'replies'}',
                style: UbuntuText.body.copyWith(color: UbuntuColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        // Replies list
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Column(
              children: comment.replies.map((r) => _CommentRow(
                comment:    r,
                currentUid: currentUid,
                isReply:    true,
                onReply:    () => onReply(r),
                onLike:     () => onLike(r),
              )).toList(),
            ),
          ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentModel comment;
  final String       currentUid;
  final bool         isReply;
  final VoidCallback onReply;
  final VoidCallback onLike;

  const _CommentRow({
    required this.comment,
    required this.currentUid,
    required this.isReply,
    required this.onReply,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked  = comment.likedBy.contains(currentUid);
    final avatarSz = isReply ? 28.0 : 36.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UbuntuAvatar(url: comment.profileImageUrl, name: comment.username, size: avatarSz),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username + text
                RichText(
                  text: TextSpan(
                    style: UbuntuText.body.copyWith(color: UbuntuColors.ink),
                    children: [
                      TextSpan(text: comment.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (comment.text.isNotEmpty) ...[
                        const TextSpan(text: '  '),
                        TextSpan(text: comment.text),
                      ],
                    ],
                  ),
                ),
                // Attached image
                if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: comment.imageUrl!,
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(height: 160, color: UbuntuColors.surface),
                        errorWidget: (_, __, ___) => Container(height: 80, color: UbuntuColors.surface,
                          child: const Icon(Icons.broken_image, color: UbuntuColors.muted)),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                // Meta row: timestamp · Reply · likes
                Row(
                  children: [
                    Text(formatTimestamp(comment.timestamp),
                      style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onReply,
                      child: Text('Reply',
                        style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted, fontWeight: FontWeight.w600)),
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(width: 14),
                      Text('${comment.likesCount} ${comment.likesCount == 1 ? 'like' : 'likes'}',
                        style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Like button
          GestureDetector(
            onTap: onLike,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isLiked ? UbuntuColors.liked : UbuntuColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode    focusNode;
  final bool         submitting;
  final bool         isReply;
  final VoidCallback onSubmit;
  final VoidCallback onPickImage;
  final String       uid;

  const _InputBar({
    required this.ctrl,
    required this.focusNode,
    required this.submitting,
    required this.isReply,
    required this.onSubmit,
    required this.onPickImage,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (_, snap) => UbuntuAvatar(
                url:  snap.data?.get('profileImageUrl') as String?,
                name: snap.data?.get('username') as String? ?? '',
                size: 32,
              ),
            ),
            const SizedBox(width: 8),
            // Image attach button
            GestureDetector(
              onTap: onPickImage,
              child: const Icon(Icons.image_outlined, color: UbuntuColors.muted, size: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller:  ctrl,
                focusNode:   focusNode,
                style:       UbuntuText.body.copyWith(color: UbuntuColors.ink),
                maxLines:    null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText:  isReply ? 'Add a reply…' : 'Add a comment…',
                  hintStyle: const TextStyle(color: UbuntuColors.muted, fontSize: 14),
                  filled:    true,
                  fillColor: UbuntuColors.input,
                  border:    OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            submitting
                ? const SizedBox(width: 28, height: 28,
                    child: CircularProgressIndicator(color: UbuntuColors.primary, strokeWidth: 2))
                : GestureDetector(
                    onTap: onSubmit,
                    child: Text(
                      isReply ? 'Reply' : 'Post',
                      style: const TextStyle(color: UbuntuColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
