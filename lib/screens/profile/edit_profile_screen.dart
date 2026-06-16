import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/gradient_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _userService   = UserService();
  final _nameCtrl      = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _bioCtrl       = TextEditingController();

  UserModel? _user;
  XFile?     _pickedImage;
  Uint8List? _imageBytes;
  bool       _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _user = user;
        _nameCtrl.text     = user.displayName;
        _usernameCtrl.text = user.username;
        _bioCtrl.text      = user.bio;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile != null && mounted) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _pickedImage = xfile;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    final name     = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (name.isEmpty || username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and username are required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _userService.updateProfile(
        displayName:  name,
        username:     username,
        bio:          _bioCtrl.text.trim(),
        profileImage: _pickedImage,
      );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: UbuntuColors.liked),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
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
        title: const Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: UbuntuColors.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  _pickedImage != null
                      ? CircleAvatar(radius: 50, backgroundImage: MemoryImage(_imageBytes!))
                      : UbuntuAvatar(url: _user?.profileImageUrl, name: _user?.displayName ?? _user?.username, size: 100, borderWidth: 1),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(color: UbuntuColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _Field(controller: _nameCtrl,     label: 'Full Name'),
            const SizedBox(height: 16),
            _Field(controller: _usernameCtrl, label: 'Username'),
            const SizedBox(height: 16),
            TextFormField(
              controller:  _bioCtrl,
              maxLines:    3,
              maxLength:   150,
              style:       UbuntuText.body.copyWith(color: UbuntuColors.ink),
              decoration: InputDecoration(
                labelText:     'Bio',
                labelStyle:    const TextStyle(color: UbuntuColors.muted, fontSize: 14),
                filled:        true,
                fillColor:     UbuntuColors.input,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UbuntuColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(label: 'Save Changes', loading: _loading, onTap: _save),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  const _Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style:      UbuntuText.body.copyWith(color: UbuntuColors.ink),
      decoration: InputDecoration(
        labelText:     label,
        labelStyle:    const TextStyle(color: UbuntuColors.muted, fontSize: 14),
        filled:        true,
        fillColor:     UbuntuColors.input,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: UbuntuColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
