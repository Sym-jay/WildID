
import 'package:flutter/material.dart' hide Badge;
import 'package:http/http.dart' as http;
import '../core/theme/app_theme.dart';
// New feature imports
import '../utils/app_utils.dart';
import 'home_screen.dart';
import '../core/services/auth_service.dart';


// ============================================================================
// MAIN APP & THEME (Legacy - to be refactored)
// ============================================================================


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
  // String? _sentOTP; // Should not store OTP client-side in production

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // In a real app, call backend API which uses Twilio/SMS service
      final otpForDemo = await AuthService.sendOTP(_phoneController.text.trim());
      if (mounted) {
        if (otpForDemo != null) {
          setState(() => _otpSent = true);
          AppUtils.showSuccess(context, 'OTP sent (Demo: $otpForDemo)'); // Show OTP only for demo
        } else {
          AppUtils.showError(context, 'Phone number not registered');
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'Failed to send OTP: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (_otpController.text.isEmpty) {
      AppUtils.showError(context, 'Please enter the OTP');
      return;
    }
    setState(() => _isLoading = true);

    try {
      // In a real app, send phone + OTP to backend for verification
      final success = await AuthService.verifyOTP(
        _phoneController.text.trim(),
        _otpController.text.trim(),
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else {
          AppUtils.showError(context, 'Invalid OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showError(context, 'Verification failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login with OTP'), elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor, AppTheme.backgroundColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sms, size: 60, color: AppTheme.primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'OTP Login',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your registered phone number',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_otpSent,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your phone number';
                            if (!RegExp(r'^\+?[0-9]{10,}$').hasMatch(value)) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              counterText: "", // Hide the counter
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_otpSent ? _handleVerifyOTP : _handleSendOTP),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                          ),
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _otpSent = false;
                                _otpController.clear();
                              });
                            },
                            child: const Text('Change Phone Number'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

