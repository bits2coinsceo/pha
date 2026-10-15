#!/usr/bin/env python3
"""Re-encrypt patient files from the old derived key to PATIENT_ENCRYPTION_KEY.

The previous backend used SHA-256("pha-patient::<API_KEY or dev>") when
PATIENT_ENCRYPTION_KEY was unset. Run this once on the server, against the
Docker volume, before starting the build that requires a real Fernet key.

Does not print file contents.

    python scripts/reencrypt_patients.py --data-dir /data/patients
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken


def legacy_fernet(api_key: str) -> Fernet:
    material = api_key if api_key else "dev"
    derived = hashlib.sha256(f"pha-patient::{material}".encode()).digest()
    return Fernet(base64.urlsafe_b64encode(derived))


def new_fernet() -> Fernet:
    raw = os.environ.get("PATIENT_ENCRYPTION_KEY", "").strip()
    if not raw:
        raise SystemExit("PATIENT_ENCRYPTION_KEY is required")
    try:
        return Fernet(raw.encode("utf-8"))
    except Exception as exc:
        raise SystemExit("PATIENT_ENCRYPTION_KEY is not a Fernet key") from exc


def strip_email(meta_path: Path) -> None:
    if not meta_path.is_file():
        return
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if "email" not in meta:
        return
    meta.pop("email", None)
    meta_path.write_text(json.dumps(meta), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", required=True)
    parser.add_argument(
        "--legacy-api-key",
        default=os.environ.get("LEGACY_API_KEY", ""),
        help="API_KEY that was set when files were written. Empty means the old 'dev' fallback.",
    )
    args = parser.parse_args()

    root = Path(args.data_dir)
    if not root.is_dir():
        raise SystemExit(f"No such directory: {root}")

    old = legacy_fernet(args.legacy_api_key.strip())
    new = new_fernet()
    blobs = sorted(root.glob("*.bin"))
    converted = 0
    skipped = 0
    for blob in blobs:
        raw = blob.read_bytes()
        try:
            plain = old.decrypt(raw)
        except InvalidToken:
            try:
                new.decrypt(raw)
            except InvalidToken:
                raise SystemExit(
                    f"Cannot decrypt {blob.name} with the legacy key or the new key. "
                    "Pass --legacy-api-key if the old server had API_KEY set."
                ) from None
            skipped += 1
            strip_email(blob.with_name(blob.name.replace(".bin", ".meta.json")))
            continue
        blob.write_bytes(new.encrypt(plain))
        strip_email(blob.with_name(blob.name.replace(".bin", ".meta.json")))
        converted += 1

    print(f"converted={converted} already_new={skipped} total={len(blobs)}")


if __name__ == "__main__":
    main()
