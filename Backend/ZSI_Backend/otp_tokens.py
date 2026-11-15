"""
Server-side one-time codes for phone login.

The server generates the code, texts it, and hands the client an opaque signed
token. To log in the client sends back the token plus the code the user typed.
The token is an HMAC over (phone, expiry, nonce, code) keyed by a server secret,
so it works across gunicorn workers / Cloud Run instances without shared
storage, and the client cannot recover the code from it.

Attempt and resend limits are kept in process memory: they are a best-effort
brake (each worker enforces its own), not the only line of defence. The code
space (10^6), 5-minute expiry and per-worker attempt cap keep guessing odds low.
"""

import base64
import hashlib
import hmac
import json
import secrets
import threading
import time
from typing import Dict, Optional, Tuple

CODE_LENGTH = 6
TTL_SECONDS = 5 * 60
MAX_VERIFY_ATTEMPTS = 5
RESEND_INTERVAL_SECONDS = 30
MAX_SENDS_PER_HOUR = 5


class OtpError(Exception):
    """Raised for rate limits; message is safe to show the user."""


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def normalize_phone(phone: str) -> Optional[str]:
    """Return the last 10 digits of an Indian mobile number, or None."""
    digits = "".join(ch for ch in str(phone) if ch.isdigit())
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    if len(digits) != 10 or digits[0] not in "6789":
        return None
    return digits


class OtpIssuer:
    def __init__(self, secret: str, clock=time.time):
        if not secret or len(secret) < 16:
            raise ValueError("OTP secret must be at least 16 characters")
        self._key = secret.encode("utf-8")
        self._clock = clock
        self._lock = threading.Lock()
        self._sends: Dict[str, list] = {}      # phone -> send timestamps
        self._attempts: Dict[str, Tuple[int, float]] = {}  # nonce -> (failures, expiry)
        self._used: Dict[str, float] = {}      # nonce -> expiry (single use)

    def _sign(self, payload_b64: str, code: str) -> str:
        mac = hmac.new(self._key, f"{payload_b64}.{code}".encode(), hashlib.sha256)
        return _b64(mac.digest())

    def _prune(self, now: float) -> None:
        for nonce, exp in list(self._used.items()):
            if exp < now:
                del self._used[nonce]
        for nonce, (_, exp) in list(self._attempts.items()):
            if exp < now:
                del self._attempts[nonce]
        for phone, times in list(self._sends.items()):
            recent = [t for t in times if now - t < 3600]
            if recent:
                self._sends[phone] = recent
            else:
                del self._sends[phone]

    def issue(self, phone: str) -> Tuple[str, str]:
        """Return (code, token) for a normalized phone. Raises OtpError on rate limit."""
        now = self._clock()
        with self._lock:
            self._prune(now)
            times = self._sends.get(phone, [])
            if times and now - times[-1] < RESEND_INTERVAL_SECONDS:
                raise OtpError("Please wait a few seconds before requesting another code.")
            if len(times) >= MAX_SENDS_PER_HOUR:
                raise OtpError("Too many codes requested. Try again in an hour.")
            self._sends[phone] = times + [now]

        code = "".join(secrets.choice("0123456789") for _ in range(CODE_LENGTH))
        payload = {"p": phone, "e": int(now + TTL_SECONDS), "n": secrets.token_urlsafe(12)}
        payload_b64 = _b64(json.dumps(payload, separators=(",", ":")).encode())
        return code, f"{payload_b64}.{self._sign(payload_b64, code)}"

    def verify(self, phone: str, code: str, token: str) -> bool:
        """True only for the right code, same phone, unexpired, unused token."""
        try:
            payload_b64, sig = token.split(".", 1)
            payload = json.loads(_unb64(payload_b64))
            nonce, exp, token_phone = str(payload["n"]), float(payload["e"]), payload["p"]
        except (ValueError, KeyError, TypeError):
            return False

        now = self._clock()
        if token_phone != phone or exp < now:
            return False

        with self._lock:
            self._prune(now)
            failures = self._attempts.get(nonce, (0, exp))[0]
            if failures >= MAX_VERIFY_ATTEMPTS:
                raise OtpError("Too many wrong codes. Request a new one.")
            if nonce in self._used:
                return False

            ok = hmac.compare_digest(self._sign(payload_b64, str(code).strip()), sig)
            if ok:
                self._used[nonce] = exp
                self._attempts.pop(nonce, None)
            else:
                self._attempts[nonce] = (failures + 1, exp)
            return ok
