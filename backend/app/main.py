"""PHA backend — FastAPI поверх Vertex AI Gemini."""
from __future__ import annotations

from contextlib import asynccontextmanager
from typing import Literal

import hashlib
import hmac

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Request,
    UploadFile,
)
from pydantic import BaseModel, ConfigDict, Field

from .config import settings
from . import usage, vertex, patient_store, otp_store, promo_store, rate_limit
from .email_service import (
    EmailDeliveryError,
    send_already_registered,
    send_password_reset_code,
    send_registration_code,
)

# Уровень сложности → какую модель использовать (см. settings.model_for).
# Сейчас оба уровня по умолчанию идут на gemini-1.5-flash, потому что более
# новые Flash-модели упирались в rate limits на фото-запросах.
Complexity = Literal["simple", "complex"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.require_production_secrets()
    vertex.init_vertex()
    yield


app = FastAPI(
    title="PHA Backend",
    version="0.1.0",
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

_MAX_CHAT_CHARS = 16_000
_MAX_TEXT_LOG_CHARS = 32_000
_MAX_UPLOAD_BYTES = 8 * 1024 * 1024


def _secret_equal(left: str, right: str) -> bool:
    return hmac.compare_digest(
        hashlib.sha256(left.encode()).digest(),
        hashlib.sha256(right.encode()).digest(),
    )


def require_api_key(
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
) -> None:
    """Всегда требует X-API-Key. Пустой API_KEY не отключает проверку."""
    if not settings.api_key or not x_api_key or not _secret_equal(x_api_key, settings.api_key):
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
    user_id: str = ""
    message: str = Field(max_length=_MAX_CHAT_CHARS)
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


class EmailCodeRequest(BaseModel):
    email: str


class VerifyRegistrationRequest(BaseModel):
    email: str
    code: str


class VerifyPasswordResetRequest(BaseModel):
    email: str
    code: str
    new_sync_token: str


class AuthOkResponse(BaseModel):
    ok: bool = True
    email: str
    registration_ticket: str | None = None


class SessionResponse(BaseModel):
    ok: bool = True
    email: str
    sync_token: str
    user_id: str


class RegisterAccountRequest(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=200)
    user_id: str = Field(min_length=8, max_length=80)
    registration_ticket: str = Field(min_length=16, max_length=200)


class SessionRequest(BaseModel):
    email: str
    password: str = Field(min_length=1, max_length=200)


class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str = Field(min_length=8, max_length=200)


class PromoRedeemRequest(BaseModel):
    code: str = Field(min_length=1, max_length=80)
    device_id: str = Field(min_length=16, max_length=128)


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
    bad_habit_checks: list[dict] = Field(default_factory=list)
    physical_activity_programs: list[dict] = Field(default_factory=list)
    physical_activity_checkins: list[dict] = Field(default_factory=list)


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


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _otp_http_error(reason: str) -> HTTPException:
    if reason == "expired":
        return HTTPException(status_code=400, detail="code_expired")
    if reason == "too_many":
        return HTTPException(status_code=429, detail="too_many_attempts")
    return HTTPException(status_code=400, detail="invalid_code")


@app.post(
    "/api/auth/register-send-code",
    response_model=AuthOkResponse,
    dependencies=[Depends(require_api_key)],
)
def register_send_code(body: EmailCodeRequest, request: Request) -> AuthOkResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "register")
    if "@" not in email or len(email) < 5:
        raise HTTPException(status_code=400, detail="invalid_email")
    # Same response whether or not the email is already registered.
    if patient_store.patient_exists(email):
        try:
            send_already_registered(email)
        except EmailDeliveryError as exc:
            raise HTTPException(status_code=502, detail="email_delivery_failed") from exc
        return AuthOkResponse(email=email)
    try:
        code = otp_store.issue_code(email, otp_store.PURPOSE_REGISTRATION)
        send_registration_code(email, code)
    except ValueError as exc:
        _raise_otp_value(exc)
    except EmailDeliveryError as exc:
        raise HTTPException(status_code=502, detail="email_delivery_failed") from exc
    return AuthOkResponse(email=email)


@app.post(
    "/api/auth/register-verify",
    response_model=AuthOkResponse,
    dependencies=[Depends(require_api_key)],
)
def register_verify(body: VerifyRegistrationRequest, request: Request) -> AuthOkResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "register-verify")
    reason = otp_store.verify_code(email, otp_store.PURPOSE_REGISTRATION, body.code)
    if reason:
        raise _otp_http_error(reason)
    ticket = otp_store.issue_registration_ticket(email)
    return AuthOkResponse(email=email, registration_ticket=ticket)


@app.post(
    "/api/auth/register-account",
    response_model=SessionResponse,
    dependencies=[Depends(require_api_key)],
)
def register_account(body: RegisterAccountRequest, request: Request) -> SessionResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "register-account")
    if not otp_store.consume_registration_ticket(email, body.registration_ticket):
        raise HTTPException(status_code=400, detail="invalid_code")
    try:
        token = patient_store.create_account(email, body.password, body.user_id)
    except FileExistsError:
        raise HTTPException(status_code=400, detail="invalid_code") from None
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="invalid_password") from exc
    return SessionResponse(email=email, sync_token=token, user_id=body.user_id)


@app.post(
    "/api/auth/session",
    response_model=SessionResponse,
    dependencies=[Depends(require_api_key)],
)
def open_session(body: SessionRequest, request: Request) -> SessionResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "session")
    try:
        token, user_id = patient_store.open_session(email, body.password)
    except PermissionError:
        raise HTTPException(status_code=401, detail="invalid_credentials") from None
    return SessionResponse(email=email, sync_token=token, user_id=user_id)


@app.post(
    "/api/auth/forgot-password-send-code",
    response_model=AuthOkResponse,
    dependencies=[Depends(require_api_key)],
)
def forgot_password_send_code(body: EmailCodeRequest, request: Request) -> AuthOkResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "reset")
    if "@" not in email or len(email) < 5:
        raise HTTPException(status_code=400, detail="invalid_email")
    if patient_store.patient_exists(email):
        try:
            code = otp_store.issue_code(email, otp_store.PURPOSE_PASSWORD_RESET)
            send_password_reset_code(email, code)
        except ValueError as exc:
            _raise_otp_value(exc)
        except EmailDeliveryError as exc:
            raise HTTPException(status_code=502, detail="email_delivery_failed") from exc
    return AuthOkResponse(email=email)


@app.post(
    "/api/auth/forgot-password-verify",
    response_model=AuthOkResponse,
    dependencies=[Depends(require_api_key)],
)
def forgot_password_verify(body: ResetPasswordRequest, request: Request) -> AuthOkResponse:
    email = _normalize_email(body.email)
    _limit_auth(request, email, "reset-verify")
    reason = otp_store.verify_code(email, otp_store.PURPOSE_PASSWORD_RESET, body.code)
    if reason:
        raise _otp_http_error(reason)
    try:
        patient_store.set_password(email, body.new_password)
    except FileNotFoundError:
        raise HTTPException(status_code=400, detail="invalid_code") from None
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="invalid_password") from exc
    return AuthOkResponse(email=email)


def _limit_auth(request: Request, email: str, action: str) -> None:
    ip = rate_limit.client_ip(request)
    rate_limit.enforce(f"{action}:ip:{ip}", 20, 15 * 60)
    rate_limit.enforce(f"{action}:email:{email}", 8, 15 * 60)


def _raise_otp_value(exc: ValueError) -> None:
    reason = str(exc)
    if reason in {"resend_too_soon", "too_many"}:
        raise HTTPException(status_code=429, detail="resend_too_soon") from exc
    raise HTTPException(status_code=400, detail="invalid_code") from exc


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get(
    "/usage",
    response_model=UsageResponse,
    dependencies=[Depends(require_api_key)],
)
def get_usage(auth: tuple[str, str] = Depends(require_patient_auth)) -> UsageResponse:
    email, _token = auth
    try:
        patient_store.assert_token(email, _token)
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
    spent = usage.get_spent(email)
    return UsageResponse(
        user_id=email,
        spent_usd=spent,
        remaining_usd=max(0.0, settings.user_budget_usd - spent),
        limit_usd=settings.user_budget_usd,
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
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
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
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
    return PatientHistoryResponse(**saved)


@app.post(
    "/patient/promo",
    dependencies=[Depends(require_api_key)],
)
def redeem_promo(
    body: PromoRedeemRequest,
    request: Request,
    auth: tuple[str, str] = Depends(require_patient_auth),
) -> dict:
    email, sync_token = auth
    rate_limit.enforce(f"promo:ip:{rate_limit.client_ip(request)}", 20, 3600)
    try:
        patient_store.assert_token(email, sync_token)
        grant = promo_store.redeem(email, body.device_id, body.code)
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
    except ValueError as exc:
        reason = str(exc)
        if reason == "already_used":
            raise HTTPException(status_code=409, detail="already_used") from exc
        raise HTTPException(status_code=400, detail="invalid_code") from exc
    return grant


@app.post("/chat", response_model=ChatResponse, dependencies=[Depends(require_api_key)])
def chat(
    req: ChatRequest,
    request: Request,
    auth: tuple[str, str] = Depends(require_patient_auth),
) -> ChatResponse:
    email, sync_token = auth
    try:
        patient_store.assert_token(email, sync_token)
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
    rate_limit.enforce(f"chat:{email}", 40, 3600)
    rate_limit.enforce(f"chat:ip:{rate_limit.client_ip(request)}", 60, 3600)
    check_budget(email)
    model_name = settings.model_for(req.complexity)
    try:
        reply, in_tok, out_tok = vertex.generate_text(req.message, model_name)
    except Exception as exc:
        _raise_model_error(exc)

    cost = settings.cost_usd(model_name, in_tok, out_tok)
    usage.add_cost(email, cost)
    return ChatResponse(
        reply=reply,
        model=model_name,
        cost_usd=cost,
        remaining_usd=usage.remaining(email),
    )


@app.post(
    "/analyze",
    response_model=AnalyzeResponse,
    dependencies=[Depends(require_api_key)],
)
async def analyze(
    request: Request,
    text_logs: str = Form(default=""),
    pdf: UploadFile | None = File(default=None),
    # Мед-анализ по умолчанию идёт на сложную модель; можно переопределить.
    complexity: Complexity = Form(default="complex"),
    auth: tuple[str, str] = Depends(require_patient_auth),
) -> AnalyzeResponse:
    email, sync_token = auth
    try:
        patient_store.assert_token(email, sync_token)
    except PermissionError:
        raise HTTPException(status_code=403, detail="forbidden") from None
    if len(text_logs) > _MAX_TEXT_LOG_CHARS:
        raise HTTPException(status_code=413, detail="file_too_large")
    rate_limit.enforce(f"analyze:{email}", 20, 3600)
    rate_limit.enforce(f"analyze:ip:{rate_limit.client_ip(request)}", 30, 3600)
    check_budget(email)
    pdf_bytes: bytes | None = None
    mime_type = "application/pdf"
    if pdf is not None:
        pdf_bytes = await pdf.read(_MAX_UPLOAD_BYTES + 1)
        if len(pdf_bytes) > _MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="file_too_large")
        mime_type = pdf.content_type or "application/pdf"

    model_name = settings.model_for(complexity)
    try:
        analysis, in_tok, out_tok = vertex.analyze_medical_data(
            text_logs, model_name, pdf_bytes, mime_type
        )
    except Exception as exc:
        _raise_model_error(exc)

    cost = settings.cost_usd(model_name, in_tok, out_tok)
    usage.add_cost(email, cost)
    return AnalyzeResponse(
        analysis=analysis,
        model=model_name,
        cost_usd=cost,
        remaining_usd=usage.remaining(email),
    )
