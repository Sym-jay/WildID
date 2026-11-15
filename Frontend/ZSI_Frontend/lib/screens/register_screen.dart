import 'package:flutter/material.dart';

import '../core/config/error_handler.dart';
import '../core/services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.registerUser(
        _emailController.text.trim(),
        _passwordController.text,
        _phoneController.text.trim(),
      );
      await AuthService.loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Account created. Welcome to WildID.')));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Your phone number lets WildID text you when an expert checks your report.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email, like name@example.com';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '98765 43210',
                ),
                validator: (v) {
                  final digits = AuthService.normalizePhone(v ?? '');
                  if (digits.isEmpty) return 'Enter your mobile number';
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                    return 'Enter a 10-digit Indian mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Choose a password';
                  if (v.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleRegister(),
                decoration: const InputDecoration(
                  labelText: 'Repeat password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v != _passwordController.text ? 'The passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 15)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: Text(_isLoading ? 'Creating account…' : 'Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
