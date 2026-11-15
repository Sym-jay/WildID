// lib/core/services/password_hasher.dart
//
// Salted PBKDF2-HMAC-SHA256 password hashing. Pure Dart, so it can run inside
// `compute()` on a background isolate (and on the main thread on web).
//
// Stored format: pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  static const String scheme = 'pbkdf2-sha256';
  static const int defaultIterations = 100000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  /// Hash [password] with a fresh random salt.
  static String hash(String password, {int iterations = defaultIterations}) {
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => rng.nextInt(256)),
    );
    final key = pbkdf2(utf8.encode(password), salt, iterations, _keyLength);
    return '$scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  /// Check [password] against a value produced by [hash].
  /// Returns false (never throws) for malformed or unknown formats.
  static bool verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != scheme) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = pbkdf2(
        utf8.encode(password),
        salt,
        iterations,
        expected.length,
      );
      return constantTimeEquals(actual, expected);
    } on FormatException {
      return false;
    }
  }

  /// True if [stored] is in the current format with the current work factor.
  static bool isCurrent(String stored) {
    final parts = stored.split('\$');
    return parts.length == 4 &&
        parts[0] == scheme &&
        int.tryParse(parts[1]) == defaultIterations;
  }

  /// PBKDF2 (RFC 8018) with HMAC-SHA256 as the PRF.
  static Uint8List pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    const blockSize = 32; // SHA-256 output length
    final blocks = (keyLength + blockSize - 1) ~/ blockSize;
    final out = BytesBuilder(copy: false);

    for (var i = 1; i <= blocks; i++) {
      final saltAndIndex = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..[salt.length] = (i >> 24) & 0xff
        ..[salt.length + 1] = (i >> 16) & 0xff
        ..[salt.length + 2] = (i >> 8) & 0xff
        ..[salt.length + 3] = i & 0xff;

      var u = hmac.convert(saltAndIndex).bytes;
      final t = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.takeBytes(), 0, keyLength);
  }

  /// Compare two byte lists without leaking where they differ via timing.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
