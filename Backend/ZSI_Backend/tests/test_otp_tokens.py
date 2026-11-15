import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import otp_tokens
from otp_tokens import OtpError, OtpIssuer, normalize_phone

SECRET = "test-secret-at-least-16-chars"


class Clock:
    def __init__(self):
        self.now = 1_000_000.0

    def __call__(self):
        return self.now


class NormalizePhoneTest(unittest.TestCase):
    def test_accepts_common_formats(self):
        for raw in ("9876543210", "+91 98765 43210", "919876543210", "98765-43210"):
            self.assertEqual(normalize_phone(raw), "9876543210")

    def test_rejects_invalid(self):
        for raw in ("", "12345", "1234567890", "+1 415 555 0100x"):
            self.assertIsNone(normalize_phone(raw))


class OtpIssuerTest(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.issuer = OtpIssuer(SECRET, clock=self.clock)

    def test_rejects_short_secret(self):
        with self.assertRaises(ValueError):
            OtpIssuer("short")

    def test_code_shape_and_not_in_token(self):
        code, token = self.issuer.issue("9876543210")
        self.assertRegex(code, r"^\d{6}$")
        self.assertNotIn(code, token)

    def test_correct_code_verifies_once(self):
        code, token = self.issuer.issue("9876543210")
        self.assertTrue(self.issuer.verify("9876543210", code, token))
        self.assertFalse(self.issuer.verify("9876543210", code, token))

    def test_wrong_code_phone_or_secret_fails(self):
        code, token = self.issuer.issue("9876543210")
        wrong = "000000" if code != "000000" else "111111"
        self.assertFalse(self.issuer.verify("9876543210", wrong, token))
        self.assertFalse(self.issuer.verify("9123456789", code, token))
        other = OtpIssuer("a-different-secret-value", clock=self.clock)
        self.assertFalse(other.verify("9876543210", code, token))

    def test_tampered_or_garbage_token_fails(self):
        code, token = self.issuer.issue("9876543210")
        payload, sig = token.split(".", 1)
        self.assertFalse(self.issuer.verify("9876543210", code, payload + "." + sig[::-1]))
        for junk in ("", "abc", "a.b", "!!!.???"):
            self.assertFalse(self.issuer.verify("9876543210", code, junk))

    def test_expired_token_fails(self):
        code, token = self.issuer.issue("9876543210")
        self.clock.now += otp_tokens.TTL_SECONDS + 1
        self.assertFalse(self.issuer.verify("9876543210", code, token))

    def test_attempt_limit_blocks_even_correct_code(self):
        code, token = self.issuer.issue("9876543210")
        wrong = "000000" if code != "000000" else "111111"
        for _ in range(otp_tokens.MAX_VERIFY_ATTEMPTS):
            self.assertFalse(self.issuer.verify("9876543210", wrong, token))
        with self.assertRaises(OtpError):
            self.issuer.verify("9876543210", code, token)

    def test_resend_interval_and_hourly_cap(self):
        self.issuer.issue("9876543210")
        with self.assertRaises(OtpError):
            self.issuer.issue("9876543210")
        for _ in range(otp_tokens.MAX_SENDS_PER_HOUR - 1):
            self.clock.now += otp_tokens.RESEND_INTERVAL_SECONDS + 1
            self.issuer.issue("9876543210")
        self.clock.now += otp_tokens.RESEND_INTERVAL_SECONDS + 1
        with self.assertRaises(OtpError):
            self.issuer.issue("9876543210")
        self.clock.now += 3600
        self.issuer.issue("9876543210")


if __name__ == "__main__":
    unittest.main()
