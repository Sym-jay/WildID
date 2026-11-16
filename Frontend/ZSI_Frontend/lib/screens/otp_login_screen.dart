import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/error_handler.dart';
import '../core/services/auth_service.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';

class OTPLoginScreen extends StatefulWidget {
  const OTPLoginScreen({super.key});

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _show(String text, {bool error = false}) => setState(() {
    _message = text;
    _messageIsError = error;
  });

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      // The backend generates, texts and later checks the code.
      final result = await AuthService.sendOTP(_phoneController.text.trim());
      if (!mounted) return;
      if (result.sent) {
        setState(() => _otpSent = true);
        // devCode only comes from a backend running with ZSI_OTP_DEV_ECHO=1.
        _show(
          result.devCode == null
              ? 'We sent a 6-digit code by SMS. It works for 5 minutes.'
              : 'Test server code: ${result.devCode}',
        );
      } else {
        _show('Could not send the code. Try again.', error: true);
      }
    } on AppException catch (e) {
      if (mounted) _show(e.message, error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      _show('Enter the 6-digit code from the SMS.', error: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await AuthService.verifyOTP(
        _phoneController.text.trim(),
        _otpController.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      } else {
        _show(
          'That code is not right. Check the SMS and try again.',
          error: true,
        );
      }
    } on AppException catch (e) {
      if (mounted) _show(e.message, error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: 'Sign in by SMS',
      subtitle:
          'Use the mobile number on your WildID account. We text you a one-time code.',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_otpSent,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '98765 43210',
              ),
              validator: (v) {
                final digits = AuthService.normalizePhone(v ?? '');
                if (digits.isEmpty) return 'Enter your mobile number';
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits))
                  return 'Enter a 10-digit Indian mobile number';
                return null;
              },
            ),
            if (_otpSent) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                autofocus: true,
                onFieldSubmitted: (_) => _handleVerifyOTP(),
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  fontSize: 15,
                  color: _messageIsError
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : (_otpSent ? _handleVerifyOTP : _handleSendOTP),
              child: Text(
                _isLoading
                    ? 'Please wait…'
                    : _otpSent
                    ? 'Sign in'
                    : 'Send code',
              ),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _otpSent = false;
                  _otpController.clear();
                  _message = null;
                }),
                child: const Text('Use a different number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
