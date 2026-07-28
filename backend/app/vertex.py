"""Обёртка над Vertex AI Gemini.

Аутентификация выполняется автоматически по переменной окружения
GOOGLE_APPLICATION_CREDENTIALS, указывающей на JSON-ключ сервис-аккаунта.
Защищённый эндпоинт Vertex AI не использует данные пациентов для обучения.
"""
from __future__ import annotations

import logging
import time

import vertexai
from vertexai.generative_models import GenerativeModel, Part

from .config import settings

logger = logging.getLogger(__name__)

# Кэш инстансов моделей по имени, чтобы не пересоздавать на каждый запрос.
_models: dict[str, GenerativeModel] = {}


def init_vertex() -> None:
    """Инициализация SDK. Вызывается один раз при старте приложения."""
    vertexai.init(project=settings.gcp_project, location=settings.gcp_location)


def _get_model(model_name: str) -> GenerativeModel:
    model = _models.get(model_name)
    if model is None:
        model = GenerativeModel(model_name)
        _models[model_name] = model
    return model


def _token_counts(response) -> tuple[int, int]:
    """Извлекает (входные, выходные) токены из ответа модели."""
    meta = getattr(response, "usage_metadata", None)
    in_tokens = int(getattr(meta, "prompt_token_count", 0) or 0)
    out_tokens = int(getattr(meta, "candidates_token_count", 0) or 0)
    return in_tokens, out_tokens


def _is_retryable_vertex_error(exc: Exception) -> bool:
    """Retry quota/rate-limit and temporary transport errors from Vertex AI."""
    message = str(exc).lower()
    return (
        "429" in message
        or "resource has been exhausted" in message
        or "resource_exhausted" in message
        or "rate limit" in message
        or "quota" in message
        or "timeout" in message
        or "temporarily unavailable" in message
        or "503" in message
        or "504" in message
    )


def _generate_with_retry(model_name: str, parts: list[object], max_attempts: int = 5):
    """Call Gemini with exponential backoff: 1s, 2s, 4s, 8s."""
    model = _get_model(model_name)
    for attempt in range(max_attempts):
        try:
            return model.generate_content(parts)
        except Exception as exc:
            is_last = attempt == max_attempts - 1
            if is_last or not _is_retryable_vertex_error(exc):
                raise

            delay = 2**attempt
            logger.warning(
                "Gemini retry %s/%s for %s after %ss: %s",
                attempt + 1,
                max_attempts,
                model_name,
                delay,
                exc,
            )
            time.sleep(delay)

    raise RuntimeError("Max retries reached for Gemini call")


def generate_text(message: str, model_name: str) -> tuple[str, int, int]:
    """Простой текстовый запрос к выбранной модели (чат).

    Возвращает (текст ответа, входные токены, выходные токены).
    """
    response = _generate_with_retry(model_name, [message])
    in_tokens, out_tokens = _token_counts(response)
    return response.text, in_tokens, out_tokens


def analyze_medical_data(
    text_logs: str,
    model_name: str,
    pdf_bytes: bytes | None = None,
    mime_type: str = "application/pdf",
) -> tuple[str, int, int]:
    """Анализ мед-данных: текст анализов + опциональный снимок КТ/МРТ (PDF).

    Воспроизводит логику исходного примера: модель сопоставляет текст и
    изображения, выявляет патологии.
    """
    prompt = (
        "Проведи анализ медицинских данных, сопоставь текст и снимки. "
        "Выяви патологии:"
    )
    parts: list[object] = [prompt, text_logs]
    if pdf_bytes:
        parts.append(Part.from_data(data=pdf_bytes, mime_type=mime_type))

    response = _generate_with_retry(model_name, parts)
    in_tokens, out_tokens = _token_counts(response)
    return response.text, in_tokens, out_tokens
