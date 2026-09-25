"""Transactional email via Twilio Email API (Basic Auth)."""
from __future__ import annotations

import base64
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .config import settings

_ENDPOINT = "https://comms.twilio.com/v1/Emails"

_REGISTRATION_SUBJECT = "Код подтверждения регистрации PHA"
_RESET_SUBJECT = "Сброс пароля PHA"

_REGISTRATION_HTML = """<div style="font-family: Arial, sans-serif; padding: 20px;">
  <h2>Добро пожаловать в PHA!</h2>
  <p>Используйте этот 6-значный код для подтверждения вашего email адреса:</p>
  <h1 style="color: #4A90E2; letter-spacing: 4px;">{code}</h1>
  <p>Код действителен в течение 10 минут.</p>
</div>"""

_RESET_HTML = """<div style="font-family: Arial, sans-serif; padding: 20px;">
  <h2>Запрос на сброс пароля</h2>
  <p>Мы получили запрос на восстановление доступа к вашему аккаунту PHA. Ваш код для сброса пароля:</p>
  <h1 style="color: #E74C3C; letter-spacing: 4px;">{code}</h1>
  <p>Код действителен в течение 10 минут. Если вы не запрашивали сброс пароля, просто проигнорируйте это письмо.</p>
</div>"""


class EmailDeliveryError(RuntimeError):
    pass


def send_registration_code(to_email: str, code: str) -> None:
    _send(
        to_email,
        _REGISTRATION_SUBJECT,
        _REGISTRATION_HTML.format(code=code),
        f"Код подтверждения регистрации PHA: {code}. Действителен 10 минут.",
    )


def send_password_reset_code(to_email: str, code: str) -> None:
    _send(
        to_email,
        _RESET_SUBJECT,
        _RESET_HTML.format(code=code),
        f"Код сброса пароля PHA: {code}. Действителен 10 минут.",
    )


def _send(to_email: str, subject: str, html: str, text: str) -> None:
    sid = settings.twilio_email_api_key_sid
    secret = settings.twilio_email_api_secret
    if not sid or not secret:
        raise EmailDeliveryError("Twilio email credentials are not configured")

    token = base64.b64encode(f"{sid}:{secret}".encode()).decode()
    payload = {
        "from": {
            "address": settings.twilio_email_from,
            "name": settings.twilio_email_from_name,
        },
        "to": [{"address": to_email}],
        "content": {
            "subject": subject,
            "html": html,
            "text": text,
        },
    }
    req = Request(
        _ENDPOINT,
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Basic {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(req, timeout=20) as res:
            if res.status not in (200, 201, 202):
                raise EmailDeliveryError(f"Twilio email failed ({res.status})")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise EmailDeliveryError(f"Twilio email failed ({exc.code}): {detail}") from exc
    except URLError as exc:
        raise EmailDeliveryError(f"Twilio email network error: {exc.reason}") from exc
