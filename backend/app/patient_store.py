"""Encrypted per-patient health history files keyed by email.

Each patient gets one encrypted JSON file on disk. Access requires:
- App-level X-API-Key (same as other endpoints)
- Per-patient X-Sync-Token matching the password hash from the mobile app
"""
from __future__ import annotations

import base64
import hashlib
import json
import threading
from datetime import datetime, timezone
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken

from .config import settings

_lock = threading.Lock()


def _email_hash(email: str) -> str:
    return hashlib.sha256(email.strip().lower().encode()).hexdigest()


def _token_hash(sync_token: str) -> str:
    return hashlib.sha256(sync_token.encode()).hexdigest()


def _fernet() -> Fernet:
    raw_key = settings.patient_encryption_key
    if raw_key:
        return Fernet(raw_key.encode() if isinstance(raw_key, str) else raw_key)
    # Dev fallback — set PATIENT_ENCRYPTION_KEY in production.
    derived = hashlib.sha256(
        f"pha-patient::{settings.api_key or 'dev'}".encode()
    ).digest()
    return Fernet(base64.urlsafe_b64encode(derived))


def _data_dir() -> Path:
    path = Path(settings.patient_data_dir)
    path.mkdir(parents=True, exist_ok=True)
    return path


def _meta_path(email: str) -> Path:
    return _data_dir() / f"{_email_hash(email)}.meta.json"


def _blob_path(email: str) -> Path:
    return _data_dir() / f"{_email_hash(email)}.bin"


def patient_exists(email: str) -> bool:
    return _meta_path(email).exists()


def _verify_token(email: str, sync_token: str) -> None:
    meta_path = _meta_path(email)
    if not meta_path.exists():
        return
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if meta.get("token_hash") != _token_hash(sync_token):
        raise PermissionError("Invalid sync token")


def _register_token(email: str, sync_token: str) -> None:
    meta = {
        "email": email.strip().lower(),
        "token_hash": _token_hash(sync_token),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    _meta_path(email).write_text(json.dumps(meta), encoding="utf-8")


def load_history(email: str, sync_token: str) -> dict | None:
    """Returns decrypted history or None if no file exists."""
    with _lock:
        if not _blob_path(email).exists():
            return None
        _verify_token(email, sync_token)
        encrypted = _blob_path(email).read_bytes()
        try:
            plaintext = _fernet().decrypt(encrypted)
        except InvalidToken as exc:
            raise PermissionError("Could not decrypt patient data") from exc
        return json.loads(plaintext.decode("utf-8"))


def save_history(email: str, sync_token: str, payload: dict) -> dict:
    """Encrypts and stores patient history. Registers token on first write."""
    email = email.strip().lower()
    payload = dict(payload)
    payload["email"] = email
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()

    with _lock:
        meta_path = _meta_path(email)
        if meta_path.exists():
            _verify_token(email, sync_token)
        else:
            _register_token(email, sync_token)

        encrypted = _fernet().encrypt(
            json.dumps(payload, ensure_ascii=False).encode("utf-8")
        )
        _blob_path(email).write_bytes(encrypted)

        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        meta["updated_at"] = payload["updated_at"]
        meta_path.write_text(json.dumps(meta), encoding="utf-8")

    return payload
