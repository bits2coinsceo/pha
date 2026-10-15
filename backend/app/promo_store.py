"""Server-side promo codes. Once per profile and once per device."""
from __future__ import annotations

import sqlite3
import threading
from datetime import datetime, timedelta, timezone

from .config import settings

# Codes stay on the server so the app binary does not contain them.
_CODES: dict[str, tuple[str, int]] = {
    "deblockpha+30days!": ("deblockpha_30", 30),
    "7daysallfeatures!": ("7daysallfeatures", 7),
}

_lock = threading.Lock()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.otp_db)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS promo_redemptions (
          code_id TEXT NOT NULL,
          email TEXT NOT NULL,
          device_id TEXT NOT NULL,
          plan TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          redeemed_at TEXT NOT NULL,
          PRIMARY KEY (code_id, email)
        )
        """
    )
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS promo_code_device
        ON promo_redemptions (code_id, device_id)
        """
    )
    conn.commit()
    return conn


def redeem(email: str, device_id: str, code: str) -> dict:
    """Returns the grant, or raises ValueError: invalid | already_used."""
    email = email.strip().lower()
    device_id = device_id.strip()
    raw = code.strip()
    if len(device_id) < 16 or len(device_id) > 128:
        raise ValueError("invalid")
    spec = _CODES.get(raw)
    if spec is None:
        raise ValueError("invalid")
    code_id, days = spec
    now = datetime.now(timezone.utc)
    expires = (now + timedelta(days=days)).isoformat()
    with _lock:
        conn = _connect()
        try:
            row = conn.execute(
                """
                SELECT 1 FROM promo_redemptions
                WHERE code_id = ? AND (email = ? OR device_id = ?)
                """,
                (code_id, email, device_id),
            ).fetchone()
            if row is not None:
                raise ValueError("already_used")
            try:
                conn.execute(
                    """
                    INSERT INTO promo_redemptions
                      (code_id, email, device_id, plan, expires_at, redeemed_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (code_id, email, device_id, f"promo_{code_id}", expires, now.isoformat()),
                )
                conn.commit()
            except sqlite3.IntegrityError as exc:
                raise ValueError("already_used") from exc
        finally:
            conn.close()
    return {"code_id": code_id, "plan": f"promo_{code_id}", "expires_at": expires}


def active_grant(email: str) -> dict | None:
    """Latest unexpired promo for this email, if any."""
    email = email.strip().lower()
    now = datetime.now(timezone.utc).isoformat()
    with _lock:
        conn = _connect()
        try:
            rows = conn.execute(
                """
                SELECT plan, expires_at, code_id FROM promo_redemptions
                WHERE email = ? AND expires_at > ?
                ORDER BY expires_at DESC
                """,
                (email, now),
            ).fetchall()
        finally:
            conn.close()
    if not rows:
        return None
    codes = [row[2] for row in rows]
    plan, expires_at, _code = rows[0]
    return {"plan": plan, "expires_at": expires_at, "codes": codes}
