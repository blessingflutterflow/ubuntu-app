import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _auth          = AuthService();
  bool _loading  = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = await _auth.register(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        context.push('/user-details', extra: {
          'uid':         cred.user!.uid,
          'email':       _emailCtrl.text.trim(),
          'displayName': _nameCtrl.text.trim(),
        });
      }
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
      appBar: AppBar(
        backgroundColor: UbuntuColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: UbuntuColors.ink),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: UbuntuColors.ink)),
                const SizedBox(height: 4),
                const Text('Join the Ubuntu Oasis community', style: UbuntuText.body),
                const SizedBox(height: 32),
                _RegInputField(controller: _nameCtrl,  label: 'Full Name', validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                const SizedBox(height: 16),
                _RegInputField(
                  controller:  _emailCtrl,
                  label:       'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _RegInputField(
                  controller: _passwordCtrl,
                  label:      'Password',
                  obscure:    _obscure1,
                  suffix: IconButton(
                    icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility, size: 20, color: UbuntuColors.muted),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _RegInputField(
                  controller: _confirmCtrl,
                  label:      'Confirm Password',
                  obscure:    _obscure2,
                  suffix: IconButton(
                    icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility, size: 20, color: UbuntuColors.muted),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                GradientButton(label: 'Create Account', loading: _loading, onTap: _register),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: UbuntuText.body),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text('Sign in', style: TextStyle(color: UbuntuColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _RegInputField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:    controller,
      obscureText:   obscure,
      keyboardType:  keyboardType,
      validator:     validator,
      style:         UbuntuText.body.copyWith(color: UbuntuColors.ink),
      decoration: InputDecoration(
        labelText:     label,
        labelStyle:    const TextStyle(color: UbuntuColors.muted, fontSize: 14),
        filled:        true,
        fillColor:     UbuntuColors.input,
        suffixIcon:    suffix,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: UbuntuColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
