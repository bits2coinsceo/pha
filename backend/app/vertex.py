"""Обёртка над Vertex AI Gemini.

Аутентификация выполняется автоматически по переменной окружения
GOOGLE_APPLICATION_CREDENTIALS, указывающей на JSON-ключ сервис-аккаунта.
Защищённый эндпоинт Vertex AI не использует данные пациентов для обучения.
"""
from __future__ import annotations

import vertexai
from vertexai.generative_models import GenerativeModel, Part

from .config import settings

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


def generate_text(message: str, model_name: str) -> tuple[str, int, int]:
    """Простой текстовый запрос к выбранной модели (чат).

    Возвращает (текст ответа, входные токены, выходные токены).
    """
    response = _get_model(model_name).generate_content([message])
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

    response = _get_model(model_name).generate_content(parts)
    in_tokens, out_tokens = _token_counts(response)
    return response.text, in_tokens, out_tokens
