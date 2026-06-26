"""Учёт трат по user_id в SQLite.

Простое потокобезопасное хранилище: одно соединение на вызов под общим
замком. Этого достаточно для умеренной нагрузки и переживает рестарты
контейнера (файл монтируется как volume).
"""
from __future__ import annotations

import sqlite3
import threading

from .config import settings

_lock = threading.Lock()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(settings.usage_db)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS usage ("
        "  user_id TEXT PRIMARY KEY,"
        "  cost_usd REAL NOT NULL DEFAULT 0"
        ")"
    )
    return conn


def get_spent(user_id: str) -> float:
    with _lock, _connect() as conn:
        row = conn.execute(
            "SELECT cost_usd FROM usage WHERE user_id = ?", (user_id,)
        ).fetchone()
    return float(row[0]) if row else 0.0


def add_cost(user_id: str, cost: float) -> None:
    with _lock, _connect() as conn:
        conn.execute(
            "INSERT INTO usage (user_id, cost_usd) VALUES (?, ?) "
            "ON CONFLICT(user_id) DO UPDATE SET cost_usd = cost_usd + excluded.cost_usd",
            (user_id, cost),
        )


def remaining(user_id: str) -> float:
    return max(0.0, settings.user_budget_usd - get_spent(user_id))
