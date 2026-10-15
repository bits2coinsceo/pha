"""Encrypted per-patient health history files keyed by email.

Each patient gets one encrypted JSON file on disk. Access requires:
- App-level X-API-Key (same as other endpoints)
- Per-patient X-Sync-Token matching the password hash from the mobile app
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
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
    if not raw_key:
        raise RuntimeError("PATIENT_ENCRYPTION_KEY is not set")
    return Fernet(raw_key.encode("utf-8"))


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
        raise PermissionError("forbidden")
    meta = _read_meta(meta_path)
    if not hmac.compare_digest(meta.get("token_hash") or "", _token_hash(sync_token)):
        raise PermissionError("forbidden")


def assert_token(email: str, sync_token: str) -> None:
    with _lock:
        _verify_token(email, sync_token)


def _read_meta(path: Path) -> dict:
    if not path.exists():
        return {}
    meta = json.loads(path.read_text(encoding="utf-8"))
    meta.pop("email", None)
    return meta


def _write_meta(path: Path, token_hash: str, updated_at: str, extra: dict | None = None) -> None:
    # Email stays only in the hashed filename, not in the sidecar.
    meta = _read_meta(path)
    meta["token_hash"] = token_hash
    meta["updated_at"] = updated_at
    if extra:
        meta.update(extra)
    path.write_text(json.dumps(meta), encoding="utf-8")


def _pbkdf2(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 210_000).hex()


def _legacy_sync_token(password: str) -> str:
    """Old client credential: SHA-256 of a fixed salt and the password."""
    return hashlib.sha256(f"pha-salt::{password}".encode()).hexdigest()


def _new_sync_token() -> str:
    return secrets.token_urlsafe(32)


def _encrypt_token(token: str) -> str:
    return _fernet().encrypt(token.encode("utf-8")).decode("utf-8")


def _decrypt_token(enc: str) -> str:
    return _fernet().decrypt(enc.encode("utf-8")).decode("utf-8")


def _password_fields(password: str, token: str) -> dict:
    salt = os.urandom(16)
    return {
        "password_salt": salt.hex(),
        "password_hash": _pbkdf2(password, salt),
        "sync_token_enc": _encrypt_token(token),
        "user_id": None,
    }


def _expiry(grant: dict) -> datetime:
    raw = str(grant.get("expires_at") or "").replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed


def _later_grant(left: dict | None, right: dict | None) -> dict | None:
    if left is None:
        return right
    if right is None:
        return left
    return right if _expiry(right) > _expiry(left) else left


def _overlay_entitlement(email: str, payload: dict) -> dict:
    """Plus+ in the backup comes from a promo or a verified store purchase."""
    from . import promo_store

    profile = dict(payload.get("profile") or {})
    promo = promo_store.active_grant(email)
    store = _store_grant(str(payload.get("user_id") or profile.get("id") or ""))
    grant = _later_grant(promo, store)
    profile.pop("password_hash", None)
    profile["is_plus"] = 1 if grant else 0
    profile["subscription_plan"] = grant["plan"] if grant else None
    profile["subscription_expires_at"] = grant["expires_at"] if grant else None
    profile["promo_codes_used"] = json.dumps(promo["codes"] if promo else [])
    payload["profile"] = profile
    return payload


_store_cache: dict[str, tuple[float, dict | None]] = {}


def _store_grant(user_id: str) -> dict | None:
    """Active App Store Plus+, if RevenueCat's secret key is configured."""
    import time
    from urllib.request import Request, urlopen

    secret = os.environ.get("REVENUECAT_SECRET_API_KEY", "").strip()
    if not secret or not user_id:
        return None
    now = time.time()
    cached = _store_cache.get(user_id)
    if cached is not None and now - cached[0] < 600:
        return cached[1]
    grant: dict | None = None
    try:
        req = Request(
            f"https://api.revenuecat.com/v1/subscribers/{user_id}",
            headers={"Authorization": f"Bearer {secret}", "Accept": "application/json"},
        )
        with urlopen(req, timeout=8) as res:
            data = json.loads(res.read().decode())
        ents = (data.get("subscriber") or {}).get("entitlements") or {}
        for key in ("pha_plus", "plus"):
            ent = ents.get(key)
            if not isinstance(ent, dict):
                continue
            expires = ent.get("expires_date")
            if not expires:
                grant = {
                    "plan": "store",
                    "expires_at": "2999-01-01T00:00:00+00:00",
                    "codes": [],
                }
                break
            if _expiry({"expires_at": str(expires)}) > datetime.now(timezone.utc):
                grant = {"plan": "store", "expires_at": str(expires), "codes": []}
                break
    except Exception:
        grant = cached[1] if cached is not None else None
    _store_cache[user_id] = (now, grant)
    return grant


def load_history(email: str, sync_token: str) -> dict | None:
    """Returns decrypted history or None if no file exists."""
    with _lock:
        _verify_token(email, sync_token)
        if not _blob_path(email).exists():
            return None
        encrypted = _blob_path(email).read_bytes()
        try:
            plaintext = _fernet().decrypt(encrypted)
        except InvalidToken as exc:
            raise PermissionError("Could not decrypt patient data") from exc
        data = json.loads(plaintext.decode("utf-8"))
    return _overlay_entitlement(email, data)


def save_history(email: str, sync_token: str, payload: dict) -> dict:
    """Encrypts and stores patient history. The account must already exist."""
    email = email.strip().lower()
    with _lock:
        if not _meta_path(email).exists():
            raise PermissionError("Account is not registered")
        _verify_token(email, sync_token)

    payload = dict(payload)
    payload["email"] = email
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    payload = _overlay_entitlement(email, payload)

    with _lock:
        meta_path = _meta_path(email)
        encrypted = _fernet().encrypt(
            json.dumps(payload, ensure_ascii=False).encode("utf-8")
        )
        _blob_path(email).write_bytes(encrypted)

        meta = _read_meta(meta_path)
        _write_meta(meta_path, meta["token_hash"], payload["updated_at"])

    return payload


def create_account(email: str, password: str, user_id: str) -> str:
    """Creates the account and returns a random sync token. Rejects duplicates."""
    email = email.strip().lower()
    if len(password) < 8:
        raise ValueError("invalid_password")
    with _lock:
        meta_path = _meta_path(email)
        if meta_path.exists():
            raise FileExistsError("account_exists")
        token = _new_sync_token()
        extra = _password_fields(password, token)
        extra["user_id"] = user_id
        _write_meta(meta_path, _token_hash(token), datetime.now(timezone.utc).isoformat(), extra)
        return token


def open_session(email: str, password: str) -> tuple[str, str]:
    """Checks the password and returns (sync_token, user_id).

    Legacy accounts still store SHA-256(password hash) as the token. The first
    successful password login replaces that with a random token.
    """
    email = email.strip().lower()
    with _lock:
        meta_path = _meta_path(email)
        if not meta_path.exists():
            raise PermissionError("invalid_credentials")
        meta = _read_meta(meta_path)
        now = datetime.now(timezone.utc).isoformat()
        salt_hex = meta.get("password_salt")
        pw_hash = meta.get("password_hash")
        enc = meta.get("sync_token_enc")
        if salt_hex and pw_hash and enc:
            salt = bytes.fromhex(salt_hex)
            check = _pbkdf2(password, salt)
            if not hmac.compare_digest(check, pw_hash):
                raise PermissionError("invalid_credentials")
            try:
                token = _decrypt_token(enc)
            except InvalidToken as exc:
                raise PermissionError("invalid_credentials") from exc
            return token, str(meta.get("user_id") or "")

        legacy = _legacy_sync_token(password)
        if not hmac.compare_digest(meta.get("token_hash") or "", _token_hash(legacy)):
            raise PermissionError("invalid_credentials")
        token = _new_sync_token()
        extra = _password_fields(password, token)
        if meta.get("user_id"):
            extra["user_id"] = meta["user_id"]
        _write_meta(meta_path, _token_hash(token), now, extra)
        return token, str(extra.get("user_id") or meta.get("user_id") or "")


def set_password(email: str, new_password: str) -> None:
    """Rotates the sync token after a verified password reset."""
    email = email.strip().lower()
    if len(new_password) < 8:
        raise ValueError("invalid_password")
    with _lock:
        meta_path = _meta_path(email)
        if not meta_path.exists():
            raise FileNotFoundError("account_not_found")
        meta = _read_meta(meta_path)
        token = _new_sync_token()
        extra = _password_fields(new_password, token)
        if meta.get("user_id"):
            extra["user_id"] = meta["user_id"]
        _write_meta(
            meta_path,
            _token_hash(token),
            datetime.now(timezone.utc).isoformat(),
            extra,
        )
