import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  Uint8List? _imageBytes;
  String?    _fileName;
  bool       _uploading = false;
  double     _progress  = 0;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() { _imageBytes = bytes; _fileName = xfile.name; });
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() { _imageBytes = bytes; _fileName = xfile.name; });
  }

  Future<void> _upload() async {
    if (_imageBytes == null) return;
    setState(() { _uploading = true; _progress = 0; });

    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final storyId = '${DateTime.now().millisecondsSinceEpoch}';
      final ref     = FirebaseStorage.instance
          .ref('stories/$uid/$storyId.jpg');

      final task = ref.putData(_imageBytes!);
      task.snapshotEvents.listen((snap) {
        if (mounted) setState(() => _progress = snap.bytesTransferred / snap.totalBytes);
      });
      await task;

      final url = await ref.getDownloadURL();
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        now.toDate().add(const Duration(hours: 24)),
      );

      // Save to stories/{uid}/items/{storyId}
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(uid)
          .collection('items')
          .doc(storyId)
          .set({
        'id':        storyId,
        'userId':    uid,
        'imageUrl':  url,
        'videoUrl':  null,
        'type':      'IMAGE',
        'duration':  5000,
        'createdAt': now,
        'expiresAt': expiresAt,
        'viewedBy':  [],
      });

      // Update user hasActiveStory flag
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasActiveStory': true,
        'lastStoryAt':    now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story posted!'), backgroundColor: UbuntuColors.primary),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: UbuntuColors.liked),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Story',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _imageBytes == null ? _PickerView(onGallery: _pickImage, onCamera: _pickFromCamera)
          : _PreviewView(
              bytes:     _imageBytes!,
              uploading: _uploading,
              progress:  _progress,
              onRetake:  () => setState(() { _imageBytes = null; _fileName = null; }),
              onPost:    _upload,
            ),
    );
  }
}

// ── No image selected: show pick options ─────────────────────────────────────

class _PickerView extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  const _PickerView({required this.onGallery, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories, color: Colors.white38, size: 80),
          const SizedBox(height: 24),
          const Text('Share a moment',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Stories disappear after 24 hours',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PickButton(icon: Icons.photo_library, label: 'Gallery', onTap: onGallery),
              const SizedBox(width: 24),
              _PickButton(icon: Icons.camera_alt,    label: 'Camera',  onTap: onCamera),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _PickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: UbuntuColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Image selected: preview + post button ────────────────────────────────────

class _PreviewView extends StatelessWidget {
  final Uint8List    bytes;
  final bool         uploading;
  final double       progress;
  final VoidCallback onRetake;
  final VoidCallback onPost;
  const _PreviewView({
    required this.bytes,
    required this.uploading,
    required this.progress,
    required this.onRetake,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full screen preview
        Image.memory(bytes, fit: BoxFit.contain),

        // Upload progress bar
        if (uploading)
          Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(
              value:           progress,
              backgroundColor: Colors.white24,
              valueColor:      const AlwaysStoppedAnimation(UbuntuColors.primary),
              minHeight:       4,
            ),
          ),

        // Bottom buttons
        Positioned(
          bottom: 32, left: 24, right: 24,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: uploading ? null : onRetake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GradientButton(
                  label:   uploading ? 'Posting…' : 'Post Story',
                  loading: uploading,
                  onTap:   onPost,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
