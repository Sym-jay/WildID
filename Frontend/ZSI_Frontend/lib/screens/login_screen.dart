import 'package:flutter/material.dart';

import '../core/config/error_handler.dart';
import '../core/services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';
import 'otp_login_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final success = await AuthService.loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (success) {
        _goHome();
      } else {
        setState(() => _error = 'That email and password do not match.');
      }
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
      title: 'Sign in',
      subtitle: 'Sign in to keep your reports and get SMS alerts. You can also continue as a guest.',
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your email';
                  if (!value.contains('@')) return 'Enter a valid email, like name@example.com';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error, fontSize: 15)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: Text(_isLoading ? 'Signing in…' : 'Sign in'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OTPLoginScreen()),
                ),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Sign in with a code by SMS'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(child: Text('New to WildID?')),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: const Text('Create account'),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextButton(
                onPressed: _goHome,
                child: const Text('Continue as guest'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
