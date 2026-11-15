import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/error_handler.dart';
import 'password_hasher.dart';

/// Result of asking the backend to send a one-time code.
class OtpRequestResult {
  const OtpRequestResult({required this.sent, this.devCode});

  /// True if the backend accepted the request.
  final bool sent;

  /// Only set when the backend runs with ZSI_OTP_DEV_ECHO=1 (no SMS gateway
  /// configured). Never populated in production.
  final String? devCode;
}

/// Local account store + backend-issued OTP login.
///
/// Accounts still live on the device (there is no user backend yet).
/// Passwords are stored as salted PBKDF2 hashes in secure storage.
/// OTP codes are generated, sent and checked by the backend, never here.
class AuthService {
  AuthService._();

  static const String _apiBaseUrl = String.fromEnvironment(
    'ZSI_API_BASE_URL',
    defaultValue: 'https://zsi-wildlife-api-173142698667.us-central1.run.app',
  );
  static const String _apiKey = String.fromEnvironment('ZSI_API_KEY');

  static const _storageKey = 'zsi_users_data';
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  static const _secureStorage = FlutterSecureStorage();

  static String? _currentUser;
  static String? _currentUserPhone;
  static final Map<String, String> _users = {}; // email -> password hash
  static final Map<String, String> _userPhones = {}; // email -> phone
  static final Map<String, int> _failedLoginAttempts = {};
  static final Map<String, DateTime> _loginLockout = {};
  // phone (normalized) -> signed token from the backend; holds no code.
  static final Map<String, String> _otpTokens = {};
  static bool _initialized = false;

  /// Load stored accounts from secure storage.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final stored = await _secureStorage.read(key: _storageKey);
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

  static Future<void> _saveCredentials() async {
    try {
      await _secureStorage.write(
        key: _storageKey,
        value: json.encode({'users': _users, 'phones': _userPhones}),
      );
    } catch (e, st) {
      AppLogger.logError('Failed to save credentials', e, st);
    }
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Last 10 digits, so "+91 98765 43210" and "9876543210" match.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static Future<bool> registerUser(
    String email,
    String password,
    String phone,
  ) async {
    try {
      email = _normalizeEmail(email);
      if (email.isEmpty || password.isEmpty || phone.trim().isEmpty) {
        throw ValidationException('All fields are required');
      }
      if (!email.contains('@')) {
        throw ValidationException('Invalid email format');
      }
      if (password.length < 8) {
        throw ValidationException('Password must be at least 8 characters');
      }
      if (_users.containsKey(email)) {
        throw ValidationException('Email already registered');
      }
      _users[email] = await compute(_hashInBackground, password);
      _userPhones[email] = phone.trim();
      await _saveCredentials();
      AppLogger.logInfo('User registered');
      return true;
    } catch (e, stackTrace) {
      AppLogger.logError('Registration failed', e, stackTrace);
      rethrow;
    }
  }

  static Future<bool> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      email = _normalizeEmail(email);
      if (_isLockedOut(email)) {
        throw AuthException(
          'Too many failed attempts. Please try again later.',
        );
      }

      final stored = _users[email];
      if (stored != null && await _verifyPassword(password, stored)) {
        // Upgrade legacy or weaker hashes transparently.
        if (!PasswordHasher.isCurrent(stored)) {
          _users[email] = await compute(_hashInBackground, password);
          await _saveCredentials();
          AppLogger.logInfo('Upgraded stored password hash');
        }
        _currentUser = email;
        _currentUserPhone = _userPhones[email];
        _failedLoginAttempts.remove(email);
        _loginLockout.remove(email);
        AppLogger.logInfo('User logged in');
        return true;
      }

      final attempts = (_failedLoginAttempts[email] ?? 0) + 1;
      _failedLoginAttempts[email] = attempts;
      if (attempts >= _maxLoginAttempts) {
        _loginLockout[email] = DateTime.now();
        AppLogger.logWarning('Account locked after failed login attempts');
        throw AuthException(
          'Account locked due to too many failed attempts. Try again in 15 minutes.',
        );
      }
      AppLogger.logWarning(
        'Failed login attempt ($attempts/$_maxLoginAttempts)',
      );
      return false;
    } catch (e, stackTrace) {
      if (e is AuthException) rethrow;
      AppLogger.logError('Login failed', e, stackTrace);
      throw AuthException(
        'Login failed. Please try again.',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<bool> _verifyPassword(String password, String stored) async {
    if (stored.startsWith('${PasswordHasher.scheme}\$')) {
      return compute(_verifyInBackground, [password, stored]);
    }
    // Pre-PBKDF2 format (hashCode + length). Accepted once, then upgraded.
    final legacy = password.hashCode.toString() + password.length.toString();
    return PasswordHasher.constantTimeEquals(
      utf8.encode(legacy),
      utf8.encode(stored),
    );
  }

  /// Ask the backend to text a one-time code to [phone].
  /// The phone must belong to an account registered on this device.
  static Future<OtpRequestResult> sendOTP(String phone) async {
    if (phone.trim().isEmpty) {
      throw ValidationException('Phone number is required');
    }
    if (_emailForPhone(phone) == null) {
      throw AuthException('Phone number not registered');
    }

    final body = await _postJson('/api/auth/otp/request', {'phone': phone});
    final token = body['otp_token'];
    if (body['success'] != true || token is! String || token.isEmpty) {
      return const OtpRequestResult(sent: false);
    }
    _otpTokens[normalizePhone(phone)] = token;
    final devCode = body['dev_otp'];
    AppLogger.logInfo('OTP requested');
    return OtpRequestResult(
      sent: true,
      devCode: devCode is String ? devCode : null,
    );
  }

  /// Ask the backend whether [otp] is the code it sent to [phone].
  static Future<bool> verifyOTP(String phone, String otp) async {
    if (phone.trim().isEmpty || otp.trim().isEmpty) {
      throw ValidationException('Phone and OTP are required');
    }
    final email = _emailForPhone(phone);
    if (email == null) {
      throw AuthException('Phone number not registered');
    }

    final token = _otpTokens[normalizePhone(phone)];
    if (token == null) {
      throw AuthException('Request a new code first');
    }

    final body = await _postJson(
      '/api/auth/otp/verify',
      {'phone': phone, 'otp': otp.trim(), 'otp_token': token},
      allowStatuses: const {400, 401},
    );
    if (body['verified'] != true) {
      AppLogger.logWarning('OTP rejected');
      return false;
    }

    _otpTokens.remove(normalizePhone(phone));
    _currentUser = email;
    _currentUserPhone = _userPhones[email];
    AppLogger.logInfo('User verified with OTP');
    return true;
  }

  static String? _emailForPhone(String phone) {
    final target = normalizePhone(phone);
    for (final entry in _userPhones.entries) {
      if (normalizePhone(entry.value) == target) return entry.key;
    }
    return null;
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    Set<int> allowStatuses = const {},
  }) async {
    if (_apiKey.isEmpty) {
      throw AuthException(
        'OTP login is not configured in this build (missing ZSI_API_KEY).',
      );
    }
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_apiBaseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': _apiKey,
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (e, st) {
      throw NetworkException(
        'Request timed out. Please try again.',
        originalError: e,
        stackTrace: st,
      );
    } on http.ClientException catch (e, st) {
      throw NetworkException(
        'Network error. Please check your internet connection.',
        originalError: e,
        stackTrace: st,
      );
    }

    Map<String, dynamic> body = {};
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Keep the empty body.
    }

    if (response.statusCode == 200 ||
        allowStatuses.contains(response.statusCode)) {
      return body;
    }
    final error = body['error'];
    throw AuthException(
      error is String && error.isNotEmpty
          ? error
          : 'Server error (${response.statusCode}). Please try again.',
    );
  }

  static bool _isLockedOut(String email) {
    final lockoutTime = _loginLockout[email];
    if (lockoutTime == null) return false;
    if (DateTime.now().difference(lockoutTime) > _lockoutDuration) {
      _loginLockout.remove(email);
      _failedLoginAttempts.remove(email);
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

// Top-level so `compute()` can run them on a background isolate.
String _hashInBackground(String password) => PasswordHasher.hash(password);

bool _verifyInBackground(List<String> args) =>
    PasswordHasher.verify(args[0], args[1]);
