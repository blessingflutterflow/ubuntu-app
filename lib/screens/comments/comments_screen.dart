import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../models/comment_model.dart';
import '../../services/comment_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../utils/time_utils.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postOwner;
  const CommentsScreen({super.key, required this.postId, this.postOwner = ''});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentService = CommentService();
  final _textCtrl       = TextEditingController();
  bool _submitting      = false;

  Future<String> _getPostOwnerId() async {
    final doc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
    return doc.data()?['userId'] as String? ?? '';
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final ownerId = await _getPostOwnerId();
      await _commentService.addComment(widget.postId, text, ownerId);
      _textCtrl.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
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
        title: Text(
          widget.postOwner.isNotEmpty ? '${widget.postOwner}\'s post' : 'Comments',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Divider(height: 0),
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _commentService.commentsStream(widget.postId),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: UbuntuColors.primary));
                }
                final comments = snap.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!', style: UbuntuText.body),
                  );
                }
                return ListView.builder(
                  padding:     const EdgeInsets.symmetric(vertical: 8),
                  itemCount:   comments.length,
                  itemBuilder: (_, i) => _CommentRow(comment: comments[i]),
                );
              },
            ),
          ),
          const Divider(height: 0),
          _CommentInput(ctrl: _textCtrl, submitting: _submitting, onSubmit: _submit),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final CommentModel comment;
  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UbuntuAvatar(url: comment.profileImageUrl, name: comment.username, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: UbuntuText.body.copyWith(color: UbuntuColors.ink),
                    children: [
                      TextSpan(text: comment.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: '  '),
                      TextSpan(text: comment.text),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(formatTimestamp(comment.timestamp), style: UbuntuText.timestamp.copyWith(color: UbuntuColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool         submitting;
  final VoidCallback onSubmit;
  const _CommentInput({required this.ctrl, required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
                size: 34,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller:  ctrl,
                style:       UbuntuText.body.copyWith(color: UbuntuColors.ink),
                maxLines:    null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText:      'Add a comment…',
                  hintStyle:     const TextStyle(color: UbuntuColors.muted, fontSize: 14),
                  filled:        true,
                  fillColor:     UbuntuColors.input,
                  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSubmit,
              child: submitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: UbuntuColors.primary, strokeWidth: 2))
                  : const Icon(Icons.send, color: UbuntuColors.primary, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}
