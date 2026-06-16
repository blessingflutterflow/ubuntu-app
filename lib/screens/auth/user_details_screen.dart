import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class UserDetailsScreen extends StatefulWidget {
  final Map<String, String> userData;
  const UserDetailsScreen({super.key, required this.userData});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl      = TextEditingController();
  final _auth         = AuthService();
  bool _loading        = false;
  String? _usernameError;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _usernameError = null; });

    final username = _usernameCtrl.text.trim().toLowerCase();
    final available = await _auth.isUsernameAvailable(username);
    if (!available) {
      setState(() { _usernameError = 'Username already taken'; _loading = false; });
      return;
    }

    try {
      await _auth.createUserDocument(
        uid:         widget.userData['uid']!,
        email:       widget.userData['email']!,
        displayName: widget.userData['displayName']!,
        username:    username,
        bio:         _bioCtrl.text.trim(),
      );
      if (mounted) context.go('/feed');
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UbuntuColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Set up your profile',
                  style:     TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: UbuntuColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose a username and add a bio',
                  style:     UbuntuText.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _InputField(
                  controller: _usernameCtrl,
                  label:      'Username',
                  prefix:     const Text('@', style: TextStyle(color: UbuntuColors.muted, fontSize: 14)),
                  errorText:  _usernameError,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Username is required';
                    if (v.length < 3) return 'At least 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) return 'Letters, numbers, underscores only';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller:  _bioCtrl,
                  maxLines:    3,
                  maxLength:   150,
                  style:       UbuntuText.body.copyWith(color: UbuntuColors.ink),
                  decoration: InputDecoration(
                    labelText:     'Bio (optional)',
                    labelStyle:    const TextStyle(color: UbuntuColors.muted, fontSize: 14),
                    filled:        true,
                    fillColor:     UbuntuColors.input,
                    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:   const BorderSide(color: UbuntuColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(label: 'Get Started', loading: _loading, onTap: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? prefix;
  final String? errorText;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    this.prefix,
    this.errorText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:  controller,
      validator:   validator,
      style:       UbuntuText.body.copyWith(color: UbuntuColors.ink),
      decoration: InputDecoration(
        labelText:     label,
        labelStyle:    const TextStyle(color: UbuntuColors.muted, fontSize: 14),
        prefixIcon:    prefix != null ? Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: prefix) : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        errorText:     errorText,
        filled:        true,
        fillColor:     UbuntuColors.input,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: UbuntuColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: UbuntuColors.liked, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
