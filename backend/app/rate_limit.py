"""Small in-memory rate limit. One API process is enough for this app."""
from __future__ import annotations

import threading
import time

from fastapi import HTTPException, Request

_lock = threading.Lock()
_hits: dict[str, list[float]] = {}


def client_ip(request: Request) -> str:
    # Caddy appends the real client. The first value can be spoofed by the caller.
    forwarded = request.headers.get("x-forwarded-for", "")
    if forwarded:
        parts = [part.strip() for part in forwarded.split(",") if part.strip()]
        if parts:
            return parts[-1]
    if request.client is None:
        return "unknown"
    return request.client.host


def enforce(key: str, limit: int, window_s: int) -> None:
    now = time.time()
    with _lock:
        if len(_hits) > 20_000:
            _hits.clear()
        bucket = [stamp for stamp in _hits.get(key, []) if now - stamp < window_s]
        if len(bucket) >= limit:
            raise HTTPException(status_code=429, detail="rate_limited")
        bucket.append(now)
        _hits[key] = bucket
