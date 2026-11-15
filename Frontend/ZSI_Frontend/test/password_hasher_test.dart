import 'dart:convert';

import 'package:fish_id_india/core/services/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PasswordHasher.pbkdf2', () {
    // RFC 7914 section 11 test vectors for PBKDF2-HMAC-SHA256.
    test('RFC 7914 vector, 1 iteration', () {
      final key = PasswordHasher.pbkdf2(
        utf8.encode('passwd'),
        utf8.encode('salt'),
        1,
        64,
      );
      expect(
        _hex(key),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('RFC 7914 vector, 80000 iterations', () {
      final key = PasswordHasher.pbkdf2(
        utf8.encode('Password'),
        utf8.encode('NaCl'),
        80000,
        64,
      );
      expect(
        _hex(key),
        '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
        'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
      );
    });
  });

  group('PasswordHasher.hash / verify', () {
    test('round trip and wrong password', () {
      final stored = PasswordHasher.hash('correct horse', iterations: 1000);
      expect(stored, startsWith('pbkdf2-sha256\$1000\$'));
      expect(PasswordHasher.verify('correct horse', stored), isTrue);
      expect(PasswordHasher.verify('correct horsE', stored), isFalse);
    });

    test('same password gets a different salt each time', () {
      final a = PasswordHasher.hash('pw', iterations: 1000);
      final b = PasswordHasher.hash('pw', iterations: 1000);
      expect(a, isNot(equals(b)));
    });

    test('malformed stored values never verify', () {
      for (final bad in [
        '',
        'plaintext',
        '123456789',
        'pbkdf2-sha256\$x\$aaaa\$bbbb',
        'pbkdf2-sha256\$1000\$!!!\$!!!',
        'md5\$1000\$aaaa\$bbbb',
      ]) {
        expect(PasswordHasher.verify('pw', bad), isFalse, reason: bad);
      }
    });

    test('isCurrent only for default work factor', () {
      expect(PasswordHasher.isCurrent(PasswordHasher.hash('pw')), isTrue);
      expect(
        PasswordHasher.isCurrent(PasswordHasher.hash('pw', iterations: 1000)),
        isFalse,
      );
      expect(PasswordHasher.isCurrent('12345678'), isFalse);
    });
  });
}
