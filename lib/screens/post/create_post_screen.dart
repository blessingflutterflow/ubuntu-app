import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final _postService = PostService();
  final _picker      = ImagePicker();

  List<XFile> _images   = [];
  XFile?     _video;
  bool       _loading   = false;
  String     _mediaType = 'text'; // text | image | video

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty && mounted) {
      setState(() {
        _images    = files;
        _video     = null;
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null && mounted) {
      setState(() {
        _video     = file;
        _images    = [];
        _mediaType = 'video';
      });
    }
  }

  Future<void> _post() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _images.isEmpty && _video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a caption, photo, or video')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_mediaType == 'image' && _images.isNotEmpty) {
        await _postService.createImagePost(caption, _images);
      } else if (_mediaType == 'video' && _video != null) {
        await _postService.createVideoPost(caption, _video!);
      } else {
        await _postService.createTextPost(caption);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post shared!'), backgroundColor: UbuntuColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: UbuntuColors.liked),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      appBar: AppBar(
        backgroundColor: UbuntuColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: UbuntuColors.ink),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _post,
            child: const Text('Share', style: TextStyle(color: UbuntuColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Media preview
            if (_images.isNotEmpty)
              SizedBox(
                height: 280,
                child: PageView(
                  children: _images.map((f) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(f),
                  )).toList(),
                ),
              )
            else if (_video != null)
              Container(
                height: 280,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Icon(Icons.videocam, color: Colors.white, size: 48)),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color:        UbuntuColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: UbuntuColors.divider),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: UbuntuColors.muted, size: 48),
                    const SizedBox(height: 8),
                    const Text('Add photos or video', style: TextStyle(color: UbuntuColors.muted, fontSize: 14)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Media picker row
            Row(
              children: [
                _MediaBtn(icon: Icons.image_outlined, label: 'Photo', onTap: _pickImages),
                const SizedBox(width: 12),
                _MediaBtn(icon: Icons.videocam_outlined, label: 'Video', onTap: _pickVideo),
                if (_images.isNotEmpty || _video != null) ...[
                  const SizedBox(width: 12),
                  _MediaBtn(
                    icon:  Icons.close,
                    label: 'Clear',
                    onTap: () => setState(() { _images = []; _video = null; _mediaType = 'text'; }),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Caption
            TextField(
              controller: _captionCtrl,
              maxLines:   5,
              maxLength:  2200,
              style:      UbuntuText.body.copyWith(color: UbuntuColors.ink),
              decoration: InputDecoration(
                hintText:  _images.isNotEmpty || _video != null ? 'Write a caption…' : 'What\'s on your mind?',
                hintStyle: const TextStyle(color: UbuntuColors.muted, fontSize: 14),
                filled:    true,
                fillColor: UbuntuColors.surface,
                border:    OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UbuntuColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),

            const SizedBox(height: 24),

            if (_loading) const Center(child: CircularProgressIndicator(color: UbuntuColors.primary))
            else GradientButton(label: 'Share Post', onTap: _post),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(XFile file) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover, width: double.infinity);
        }
        return Container(color: UbuntuColors.surface, child: const Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _MediaBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:        UbuntuColors.input,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: UbuntuColors.ink),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: UbuntuColors.ink)),
          ],
        ),
      ),
    );
  }
}
