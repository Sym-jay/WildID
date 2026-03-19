// lib/core/services/secure_auth_service.dart
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/error_handler.dart';

/// Secure authentication service with encrypted credential storage
class SecureAuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const String _currentUserKey = 'current_user';
  static const String _currentPhoneKey = 'current_phone';
  static const String _otpKey = 'otp_';
  static const String _attemptKey = 'login_attempts_';
  static const String _lockoutKey = 'lockout_';

  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Initialize secure storage (verify it's working)
  static Future<bool> initialize() async {
    try {
      await _secureStorage.write(
        key: '_test_key',
        value: 'test',
      );
      await _secureStorage.delete(key: '_test_key');
      AppLogger.logInfo('Secure storage initialized');
      return true;
    } catch (e, stackTrace) {
      AppLogger.logError('Secure storage initialization failed', e, stackTrace);
      throw AppError(
        'Failed to initialize secure storage',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Register user with encrypted credentials
  static Future<bool> registerUser(
    String email,
    String password,
    String phone,
  ) async {
    try {
      if (email.isEmpty || password.isEmpty || phone.isEmpty) {
        throw ValidationException('All fields are required');
      }

      // In production, validate with backend and use proper password hashing
      // For now, store encrypted locally
      await _secureStorage.write(
        key: 'user_$email',
        value: password, // In production: bcrypt hash from backend
      );
      await _secureStorage.write(
        key: 'phone_$email',
        value: phone,
      );

      AppLogger.logInfo('User registered securely: $email');
      return true;
    } catch (e, stackTrace) {
      AppLogger.logError('Secure registration failed', e, stackTrace);
      throw AppError(
        'Registration failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Login with rate limiting
  static Future<bool> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      // Check lockout status
      final lockoutUntil = await _getLoginLockout(email);
      if (lockoutUntil != null) {
        final remainingTime =
            lockoutUntil.difference(DateTime.now()).inMinutes;
        throw AuthException(
          'Account locked. Try again in $remainingTime minutes.',
        );
      }

      // Retrieve stored credentials
      final storedPassword = await _secureStorage.read(key: 'user_$email');
      final storedPhone = await _secureStorage.read(key: 'phone_$email');

      if (storedPassword == null || storedPhone == null) {
        throw AuthException('User not found');
      }

      // In production: compare bcrypt hashes instead
      if (storedPassword != password) {
        // Record failed attempt
        final attempts = await _getLoginAttempts(email);
        final newAttempts = attempts + 1;

        if (newAttempts >= _maxLoginAttempts) {
          await _setLoginLockout(email);
          AppLogger.logWarning('Account locked: $email');
          throw AuthException(
            'Too many failed attempts. Account locked for 15 minutes.',
          );
        }

        await _setLoginAttempts(email, newAttempts);
        AppLogger.logWarning('Failed login: $email (attempt $newAttempts/$_maxLoginAttempts)');
        throw AuthException('Invalid email or password');
      }

      // Clear failed attempts and save session
      await _secureStorage.delete(key: '$_attemptKey$email');
      await _secureStorage.write(key: _currentUserKey, value: email);
      await _secureStorage.write(key: _currentPhoneKey, value: storedPhone);

      AppLogger.logInfo('User logged in securely: $email');
      return true;
    } catch (e, stackTrace) {
      if (e is AuthException) rethrow;
      AppLogger.logError('Secure login failed', e, stackTrace);
      throw AuthException(
        'Login failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send OTP and store encrypted
  static Future<String?> sendOTP(String phone) async {
    try {
      if (phone.isEmpty) {
        throw ValidationException('Phone number is required');
      }

      // Generate OTP
      final otp = (Random().nextInt(900000) + 100000).toString();

      // Store encrypted with expiry (5 minutes)
      await _secureStorage.write(
        key: '$_otpKey$phone',
        value: otp,
      );
      await _secureStorage.write(
        key: '${_otpKey}expiry_$phone',
        value: DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      );

      AppLogger.logInfo('OTP sent to: $phone');
      return otp;
    } catch (e, stackTrace) {
      AppLogger.logError('OTP send failed', e, stackTrace);
      throw AuthException(
        'Failed to send OTP',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Verify OTP with expiry check
  static Future<bool> verifyOTP(String phone, String otp) async {
    try {
      if (phone.isEmpty || otp.isEmpty) {
        throw ValidationException('Phone and OTP are required');
      }

      final storedOtp = await _secureStorage.read(key: '$_otpKey$phone');
      final expiryStr = await _secureStorage.read(
        key: '${_otpKey}expiry_$phone',
      );

      if (storedOtp == null || expiryStr == null) {
        throw AuthException('OTP not found or expired');
      }

      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        await _secureStorage.delete(key: '$_otpKey$phone');
        throw AuthException('OTP has expired');
      }

      if (storedOtp != otp) {
        AppLogger.logWarning('Invalid OTP for: $phone');
        return false;
      }

      // Clear OTP and save session
      await _secureStorage.delete(key: '$_otpKey$phone');
      await _secureStorage.delete(key: '${_otpKey}expiry_$phone');
      await _secureStorage.write(key: _currentPhoneKey, value: phone);

      AppLogger.logInfo('User verified with OTP: $phone');
      return true;
    } catch (e, stackTrace) {
      if (e is AuthException) rethrow;
      AppLogger.logError('OTP verification failed', e, stackTrace);
      throw AuthException(
        'OTP verification failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Logout and clear session
  static Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _currentUserKey);
      await _secureStorage.delete(key: _currentPhoneKey);
      AppLogger.logInfo('User logged out');
    } catch (e, stackTrace) {
      AppLogger.logError('Logout failed', e, stackTrace);
    }
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final user = await _secureStorage.read(key: _currentUserKey);
      return user != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current user
  static Future<String?> getCurrentUser() async {
    try {
      return await _secureStorage.read(key: _currentUserKey);
    } catch (e) {
      return null;
    }
  }

  /// Get current phone
  static Future<String?> getCurrentPhone() async {
    try {
      return await _secureStorage.read(key: _currentPhoneKey);
    } catch (e) {
      return null;
    }
  }

  // Private helper methods
  static Future<int> _getLoginAttempts(String email) async {
    try {
      final value = await _secureStorage.read(key: '$_attemptKey$email');
      return int.tryParse(value ?? '0') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> _setLoginAttempts(String email, int count) async {
    try {
      await _secureStorage.write(
        key: '$_attemptKey$email',
        value: count.toString(),
      );
    } catch (e) {
      AppLogger.logWarning('Failed to set login attempts: $email');
    }
  }

  static Future<DateTime?> _getLoginLockout(String email) async {
    try {
      final value = await _secureStorage.read(key: '$_lockoutKey$email');
      if (value == null) return null;
      final lockoutTime = DateTime.parse(value);
      if (DateTime.now().isAfter(lockoutTime)) {
        await _secureStorage.delete(key: '$_lockoutKey$email');
        return null;
      }
      return lockoutTime;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _setLoginLockout(String email) async {
    try {
      final lockoutUntil =
          DateTime.now().add(_lockoutDuration).toIso8601String();
      await _secureStorage.write(key: '$_lockoutKey$email', value: lockoutUntil);
    } catch (e) {
      AppLogger.logWarning('Failed to set login lockout: $email');
    }
  }
}
