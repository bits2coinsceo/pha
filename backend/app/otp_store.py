"""Short-lived email OTP codes (registration + password reset)."""
from __future__ import annotations

import hashlib
import hmac
import secrets
import sqlite3
import threading
import time

from .config import settings

PURPOSE_REGISTRATION = "REGISTRATION"
PURPOSE_PASSWORD_RESET = "PASSWORD_RESET"

_lock = threading.Lock()
_MAX_ATTEMPTS = 5
_MIN_RESEND_SECONDS = 30


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.otp_db)
    try:
        _ensure_schema(conn)
    except Exception:
        conn.close()
        raise
    return conn


def _ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS otp_codes (
          email TEXT NOT NULL,
          purpose TEXT NOT NULL,
          code_hash TEXT NOT NULL,
          expires_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (email, purpose)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS verified_emails (
          email TEXT PRIMARY KEY,
          verified_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS registration_tickets (
          email TEXT PRIMARY KEY,
          ticket_hash TEXT NOT NULL,
          expires_at INTEGER NOT NULL
        )
        """
    )
    columns = {row[1] for row in conn.execute("PRAGMA table_info(otp_codes)")}
    if "attempts" not in columns:
        conn.execute(
            "ALTER TABLE otp_codes ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0"
        )
    conn.commit()


def _hash_code(code: str) -> str:
    pepper = (settings.api_key or "").encode()
    return hmac.new(pepper, code.encode(), hashlib.sha256).hexdigest()


def _codes_match(stored: str, candidate: str) -> bool:
    return hmac.compare_digest(stored, _hash_code(candidate))


def issue_code(email: str, purpose: str) -> str:
    """Stores a new 6-digit code. Raises ValueError if resent too soon."""
    email = email.strip().lower()
    now = int(time.time())
    code = f"{secrets.randbelow(1_000_000):06d}"
    with _lock:
        conn = _connect()
        try:
            row = conn.execute(
                "SELECT created_at, attempts FROM otp_codes WHERE email = ? AND purpose = ?",
                (email, purpose),
            ).fetchone()
            if row and now - int(row[0]) < _MIN_RESEND_SECONDS:
                raise ValueError("resend_too_soon")
            if row and int(row[1]) >= _MAX_ATTEMPTS:
                raise ValueError("too_many")
            # A new code does not reset the attempt counter.
            attempts = int(row[1]) if row else 0
            conn.execute(
                """
                INSERT INTO otp_codes (email, purpose, code_hash, expires_at, created_at, attempts)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(email, purpose) DO UPDATE SET
                  code_hash = excluded.code_hash,
                  expires_at = excluded.expires_at,
                  created_at = excluded.created_at,
                  attempts = otp_codes.attempts
                """,
                (
                    email,
                    purpose,
                    _hash_code(code),
                    now + settings.otp_ttl_seconds,
                    now,
                    attempts,
                ),
            )
            conn.commit()
        finally:
            conn.close()
    return code


def verify_code(email: str, purpose: str, code: str) -> str | None:
    """Returns None on success, otherwise an error token: invalid | expired | too_many."""
    email = email.strip().lower()
    now = int(time.time())
    cleaned = "".join(ch for ch in code if ch.isdigit())
    with _lock:
        conn = _connect()
        try:
            return _verify_locked(conn, email, purpose, cleaned, now)
        finally:
            conn.close()


def _verify_locked(
    conn: sqlite3.Connection,
    email: str,
    purpose: str,
    cleaned: str,
    now: int,
) -> str | None:
    row = conn.execute(
        "SELECT code_hash, expires_at, attempts FROM otp_codes WHERE email = ? AND purpose = ?",
        (email, purpose),
    ).fetchone()
    if row is None:
        return "invalid"
    code_hash, expires_at, attempts = row
    if int(attempts) >= _MAX_ATTEMPTS:
        conn.execute(
            "DELETE FROM otp_codes WHERE email = ? AND purpose = ?",
            (email, purpose),
        )
        conn.commit()
        return "too_many"
    if now > int(expires_at):
        conn.execute(
            "DELETE FROM otp_codes WHERE email = ? AND purpose = ?",
            (email, purpose),
        )
        conn.commit()
        return "expired"
    if not _codes_match(code_hash, cleaned):
        conn.execute(
            "UPDATE otp_codes SET attempts = attempts + 1 WHERE email = ? AND purpose = ?",
            (email, purpose),
        )
        conn.commit()
        return "invalid"
    conn.execute(
        "DELETE FROM otp_codes WHERE email = ? AND purpose = ?",
        (email, purpose),
    )
    if purpose == PURPOSE_REGISTRATION:
        conn.execute(
            """
            INSERT INTO verified_emails (email, verified_at)
            VALUES (?, datetime('now'))
            ON CONFLICT(email) DO UPDATE SET verified_at = excluded.verified_at
            """,
            (email,),
        )
    conn.commit()
    return None


def issue_registration_ticket(email: str) -> str:
    """Single-use ticket, 15 minutes. Required to create the account."""
    email = email.strip().lower()
    ticket = secrets.token_urlsafe(32)
    expires = int(time.time()) + 15 * 60
    with _lock:
        conn = _connect()
        try:
            conn.execute(
                """
                INSERT INTO registration_tickets (email, ticket_hash, expires_at)
                VALUES (?, ?, ?)
                ON CONFLICT(email) DO UPDATE SET
                  ticket_hash = excluded.ticket_hash,
                  expires_at = excluded.expires_at
                """,
                (email, _hash_code(ticket), expires),
            )
            conn.commit()
        finally:
            conn.close()
    return ticket


def consume_registration_ticket(email: str, ticket: str) -> bool:
    email = email.strip().lower()
    now = int(time.time())
    with _lock:
        conn = _connect()
        try:
            row = conn.execute(
                "SELECT ticket_hash, expires_at FROM registration_tickets WHERE email = ?",
                (email,),
            ).fetchone()
            if row is None or now > int(row[1]) or not _codes_match(row[0], ticket):
                return False
            conn.execute(
                "DELETE FROM registration_tickets WHERE email = ?",
                (email,),
            )
            conn.execute("DELETE FROM verified_emails WHERE email = ?", (email,))
            conn.commit()
        finally:
            conn.close()
    return True
