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
from pydantic import BaseModel, ConfigDict, Field

from .config import settings
from . import usage, vertex, patient_store

# Уровень сложности → какую модель использовать (см. settings.model_for).
# Сейчас оба уровня по умолчанию идут на gemini-1.5-flash, потому что более
# новые Flash-модели упирались в rate limits на фото-запросах.
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


def _raise_model_error(exc: Exception) -> None:
    """Map Vertex/Gemini failures to a clean client-facing HTTP error."""
    text = str(exc)
    lower = text.lower()
    if (
        "429" in text
        or "resource has been exhausted" in lower
        or "resource_exhausted" in lower
        or ("quota" in lower and "exhaust" in lower)
    ):
        raise HTTPException(
            status_code=429,
            detail="AI service is temporarily busy. Please wait a minute and try again.",
        ) from exc
    raise HTTPException(
        status_code=502,
        detail="AI analysis failed. Please try again.",
    ) from exc


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


class PatientExistsResponse(BaseModel):
    email: str
    exists: bool


class PatientHistoryResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")

    version: int = 1
    email: str
    user_id: str
    updated_at: str
    profile: dict
    health_metrics: list[dict]
    health_index: list[dict]
    ai_consultations: list[dict]
    analysis_uploads: list[dict]
    stress_tests: list[dict]
    psychotest_results: list[dict]
    health_connect_syncs: list[dict]
    health_analysis: list[dict]
    treatment_schedule: list[dict]
    meal_calorie_checks: list[dict] = Field(default_factory=list)


def require_patient_auth(
    x_patient_email: str | None = Header(default=None, alias="X-Patient-Email"),
    x_sync_token: str | None = Header(default=None, alias="X-Sync-Token"),
) -> tuple[str, str]:
    if not x_patient_email or not x_sync_token:
        raise HTTPException(
            status_code=401,
            detail="X-Patient-Email and X-Sync-Token headers are required",
        )
    return x_patient_email.strip().lower(), x_sync_token


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


@app.get(
    "/patient/exists",
    response_model=PatientExistsResponse,
    dependencies=[Depends(require_api_key)],
)
def patient_exists(email: str) -> PatientExistsResponse:
    normalized = email.strip().lower()
    return PatientExistsResponse(
        email=normalized,
        exists=patient_store.patient_exists(normalized),
    )


@app.get(
    "/patient/history",
    response_model=PatientHistoryResponse,
    dependencies=[Depends(require_api_key)],
)
def get_patient_history(
    auth: tuple[str, str] = Depends(require_patient_auth),
) -> PatientHistoryResponse:
    email, sync_token = auth
    try:
        data = patient_store.load_history(email, sync_token)
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    if data is None:
        raise HTTPException(status_code=404, detail="No history found for this email")
    return PatientHistoryResponse(**data)


@app.put(
    "/patient/history",
    response_model=PatientHistoryResponse,
    dependencies=[Depends(require_api_key)],
)
def put_patient_history(
    payload: PatientHistoryResponse,
    auth: tuple[str, str] = Depends(require_patient_auth),
) -> PatientHistoryResponse:
    email, sync_token = auth
    if payload.email.strip().lower() != email:
        raise HTTPException(status_code=400, detail="Email in body must match X-Patient-Email")
    try:
        saved = patient_store.save_history(email, sync_token, payload.model_dump())
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    return PatientHistoryResponse(**saved)


@app.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_api_key)])
def chat(req: ChatRequest) -> ChatResponse:
    check_budget(req.user_id)
    model_name = settings.model_for(req.complexity)
    try:
        reply, in_tok, out_tok = vertex.generate_text(req.message, model_name)
    except Exception as exc:
        _raise_model_error(exc)

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
        _raise_model_error(exc)

    cost = settings.cost_usd(model_name, in_tok, out_tok)
    usage.add_cost(user_id, cost)
    return AnalyzeResponse(
        analysis=analysis,
        model=model_name,
        cost_usd=cost,
        remaining_usd=usage.remaining(user_id),
    )
