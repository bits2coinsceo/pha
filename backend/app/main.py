"""PHA backend — FastAPI поверх Vertex AI Gemini."""
from __future__ import annotations

from contextlib import asynccontextmanager
from typing import Literal

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    UploadFile,
)
from pydantic import BaseModel

from .config import settings
from . import usage, vertex

# Уровень сложности → какую модель использовать (см. settings.model_for):
#   simple  → gemini-2.5-flash  (быстро/дёшево, обычные ответы)
#   complex → gemini-3.5-flash  (сложные рассуждения, мед-анализ)
Complexity = Literal["simple", "complex"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Инициализируем Vertex AI один раз на старте процесса.
    vertex.init_vertex()
    yield


app = FastAPI(title="PHA Backend", version="0.1.0", lifespan=lifespan)


def require_api_key(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
) -> None:
    """Если в окружении задан API_KEY — требуем его в заголовке X-API-Key."""
    if settings.api_key and x_api_key != settings.api_key:
        raise HTTPException(status_code=401, detail="Invalid or missing API key")


def check_budget(user_id: str) -> None:
    """Отклоняет запрос, если пользователь исчерпал лимит кредитов."""
    if usage.remaining(user_id) <= 0:
        raise HTTPException(
            status_code=402,
            detail=(
                f"Budget of ${settings.user_budget_usd:.2f} exhausted "
                f"for user '{user_id}'"
            ),
        )


class ChatRequest(BaseModel):
    user_id: str
    message: str
    # Уровень сложности выбирает модель. По умолчанию — простая.
    complexity: Complexity = "simple"


class ChatResponse(BaseModel):
    reply: str
    model: str
    cost_usd: float
    remaining_usd: float


class AnalyzeResponse(BaseModel):
    analysis: str
    model: str
    cost_usd: float
    remaining_usd: float


class UsageResponse(BaseModel):
    user_id: str
    spent_usd: float
    remaining_usd: float
    limit_usd: float


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "models": {
            "simple": settings.gemini_model_simple,
            "complex": settings.gemini_model_complex,
        },
        "project": settings.gcp_project,
        "location": settings.gcp_location,
        "user_budget_usd": settings.user_budget_usd,
    }


@app.get(
    "/usage/{user_id}",
    response_model=UsageResponse,
    dependencies=[Depends(require_api_key)],
)
def get_usage(user_id: str) -> UsageResponse:
    spent = usage.get_spent(user_id)
    return UsageResponse(
        user_id=user_id,
        spent_usd=spent,
        remaining_usd=max(0.0, settings.user_budget_usd - spent),
        limit_usd=settings.user_budget_usd,
    )


@app.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_api_key)])
def chat(req: ChatRequest) -> ChatResponse:
    check_budget(req.user_id)
    model_name = settings.model_for(req.complexity)
    try:
        reply, in_tok, out_tok = vertex.generate_text(req.message, model_name)
    except Exception as exc:  # ошибки модели/квоты отдаём как 502
        raise HTTPException(status_code=502, detail=f"Model error: {exc}") from exc

    cost = settings.cost_usd(model_name, in_tok, out_tok)
    usage.add_cost(req.user_id, cost)
    return ChatResponse(
        reply=reply,
        model=model_name,
        cost_usd=cost,
        remaining_usd=usage.remaining(req.user_id),
    )


@app.post(
    "/analyze",
    response_model=AnalyzeResponse,
    dependencies=[Depends(require_api_key)],
)
async def analyze(
    user_id: str = Form(...),
    text_logs: str = Form(default=""),
    pdf: UploadFile | None = File(default=None),
    # Мед-анализ по умолчанию идёт на сложную модель; можно переопределить.
    complexity: Complexity = Form(default="complex"),
) -> AnalyzeResponse:
    check_budget(user_id)
    pdf_bytes: bytes | None = None
    mime_type = "application/pdf"
    if pdf is not None:
        pdf_bytes = await pdf.read()
        mime_type = pdf.content_type or "application/pdf"

    model_name = settings.model_for(complexity)
    try:
        analysis, in_tok, out_tok = vertex.analyze_medical_data(
            text_logs, model_name, pdf_bytes, mime_type
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Model error: {exc}") from exc

    cost = settings.cost_usd(model_name, in_tok, out_tok)
    usage.add_cost(user_id, cost)
    return AnalyzeResponse(
        analysis=analysis,
        model=model_name,
        cost_usd=cost,
        remaining_usd=usage.remaining(user_id),
    )
