import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _auth         = AuthService();
  bool _loading       = false;
  bool _obscure       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.go('/feed');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e.toString())), backgroundColor: UbuntuColors.liked),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email')),
        );
      }
    } catch (_) {}
  }

  String _friendlyError(String e) {
    if (e.contains('user-not-found'))     return 'No account found with this email';
    if (e.contains('wrong-password'))     return 'Invalid password';
    if (e.contains('invalid-email'))      return 'Invalid email format';
    if (e.contains('network'))            return 'Network error. Please try again';
    return 'Sign in failed. Please try again';
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
                const SizedBox(height: 60),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [UbuntuColors.primary, UbuntuColors.accent],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ).createShader(b),
                  child: const Text(
                    'ubuntu',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue',
                  style:     UbuntuText.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _InputField(
                  controller:  _emailCtrl,
                  label:       'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _InputField(
                  controller: _passwordCtrl,
                  label:      'Password',
                  obscure:    _obscure,
                  suffix: IconButton(
                    icon:    Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: UbuntuColors.muted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text('Forgot password?', style: TextStyle(color: UbuntuColors.primary, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(label: 'Sign In', loading: _loading, onTap: _signIn),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: UbuntuText.body),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text('Sign up', style: TextStyle(color: UbuntuColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _InputField({
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: UbuntuColors.liked, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: UbuntuColors.liked, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
