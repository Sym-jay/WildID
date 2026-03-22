import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/error_handler.dart';

class AuthService {
  AuthService._();

  static String? _currentUser;
  static String? _currentUserPhone;
  static final Map<String, String> _users = {};
  static final Map<String, String> _userPhones = {};
  static final Map<String, String> _otpCodes = {};
  static final Map<String, int> _failedLoginAttempts = {};
  static final Random _random = Random();
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);
  static final Map<String, DateTime> _loginLockout = {};
  
  static const _secureStorage = FlutterSecureStorage();
  static bool _initialized = false;

  /// Initialize auth service and load stored credentials
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final stored = await _secureStorage.read(key: 'zsi_users_data');
      if (stored != null) {
        final Map<String, dynamic> data = json.decode(stored);
        _users.addAll(Map<String, String>.from(data['users'] ?? {}));
        _userPhones.addAll(Map<String, String>.from(data['phones'] ?? {}));
        AppLogger.logInfo('Loaded ${_users.length} stored users');
      }
      _initialized = true;
    } catch (e, st) {
      AppLogger.logError('Failed to initialize auth', e, st);
    }
  }

  /// Save credentials to secure storage
  static Future<void> _saveCredentials() async {
    try {
      final data = {
        'users': _users,
        'phones': _userPhones,
      };
      await _secureStorage.write(
        key: 'zsi_users_data',
        value: json.encode(data),
      );
    } catch (e, st) {
      AppLogger.logError('Failed to save credentials', e, st);
    }
  }

  static Future<bool> registerUser(String email, String password, String phone) async {
    try {
      if (email.isEmpty || password.isEmpty || phone.isEmpty) {
        throw ValidationException('All fields are required');
      }
      if (_users.containsKey(email)) {
        throw ValidationException('Email already registered');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      _users[email] = password;
      _userPhones[email] = phone;
      await _saveCredentials();
      AppLogger.logInfo('User registered: $email');
      return true;
    } catch (e, stackTrace) {
      AppLogger.logError('Registration failed', e, stackTrace);
      rethrow;
    }
  }

  static Future<bool> loginWithEmailPassword(String email, String password) async {
    try {
      // Check lockout
      if (_isLockedOut(email)) {
        throw AuthException('Too many failed attempts. Please try again later.');
      }

      await Future.delayed(const Duration(milliseconds: 500));
      if (_users.containsKey(email) && _users[email] == password) {
        _currentUser = email;
        _currentUserPhone = _userPhones[email];
        _failedLoginAttempts[email] = 0;
        _loginLockout.remove(email);
        AppLogger.logInfo('User logged in: $email');
        return true;
      }

      // Track failed attempt
      _failedLoginAttempts[email] = (_failedLoginAttempts[email] ?? 0) + 1;
      if (_failedLoginAttempts[email]! >= _maxLoginAttempts) {
        _loginLockout[email] = DateTime.now();
        AppLogger.logWarning('Account locked after failed login attempts: $email');
        throw AuthException('Account locked due to too many failed attempts. Try again in 15 minutes.');
      }

      AppLogger.logWarning('Failed login attempt for: $email');
      return false;
    } catch (e, stackTrace) {
      if (e is AuthException) rethrow;
      AppLogger.logError('Login failed', e, stackTrace);
      throw AuthException('Login failed. Please try again.', originalError: e, stackTrace: stackTrace);
    }
  }

  static Future<String?> sendOTP(String phone) async {
    try {
      if (phone.isEmpty) {
        throw ValidationException('Phone number is required');
      }
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_userPhones.containsValue(phone)) {
        throw AuthException('Phone number not found');
      }

      String otp = (_random.nextInt(900000) + 100000).toString();
      _otpCodes[phone] = otp;
      AppLogger.logInfo('OTP sent to: $phone');
      debugPrint('OTP for $phone: $otp');
      return otp;
    } catch (e, stackTrace) {
      AppLogger.logError('OTP send failed', e, stackTrace);
      rethrow;
    }
  }

  static Future<bool> verifyOTP(String phone, String otp) async {
    try {
      if (phone.isEmpty || otp.isEmpty) {
        throw ValidationException('Phone and OTP are required');
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (_otpCodes.containsKey(phone) && _otpCodes[phone] == otp) {
        for (var entry in _userPhones.entries) {
          if (entry.value == phone) {
            _currentUser = entry.key;
            _currentUserPhone = phone;
            _otpCodes.remove(phone);
            AppLogger.logInfo('User verified with OTP: $phone');
            return true;
          }
        }
      }
      AppLogger.logWarning('Invalid OTP for: $phone');
      return false;
    } catch (e, stackTrace) {
      AppLogger.logError('OTP verification failed', e, stackTrace);
      rethrow;
    }
  }

  static bool _isLockedOut(String email) {
    if (!_loginLockout.containsKey(email)) return false;
    final lockoutTime = _loginLockout[email]!;
    if (DateTime.now().difference(lockoutTime) > _lockoutDuration) {
      _loginLockout.remove(email);
      return false;
    }
    return true;
  }

  static void logout() {
    _currentUser = null;
    _currentUserPhone = null;
    AppLogger.logInfo('User logged out');
  }

  static bool get isLoggedIn => _currentUser != null;
  static String? get currentUser => _currentUser;
  static String? get currentUserPhone => _currentUserPhone;
}
