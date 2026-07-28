"""Конфигурация через переменные окружения.

Значения по умолчанию подобраны под проект pha-personal-health-assistant.
Переопределяются через .env / docker-compose без правки кода.
"""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    # --- GCP / Vertex AI ---
    gcp_project: str = os.environ.get("GCP_PROJECT", "pha-personal-health-assistant")
    # Use a regional endpoint for Gemini 1.5 Flash to reduce rate-limit pressure.
    gcp_location: str = os.environ.get("GCP_LOCATION", "global")

    # Keep both complexity levels on Gemini 1.5 Flash. Newer Flash models were
    # hitting quota even for a couple of photo requests in this project.
    gemini_model_simple: str = os.environ.get("GEMINI_MODEL_SIMPLE", "gemini-1.5-flash")
    gemini_model_complex: str = os.environ.get("GEMINI_MODEL_COMPLEX", "gemini-1.5-flash")

    # --- Доступ к API ---
    # Если задан — клиент обязан присылать заголовок X-API-Key с этим значением.
    api_key: str | None = os.environ.get("API_KEY") or None

    # --- Лимит кредитов на пользователя ---
    # Максимум трат на одного user_id (USD). При исчерпании запросы отклоняются.
    user_budget_usd: float = float(os.environ.get("USER_BUDGET_USD", "5"))
    # Путь к SQLite-файлу со счётчиками (в Docker монтируется как volume).
    usage_db: str = os.environ.get("USAGE_DB", "usage.db")

    # --- Хранение истории пациента (зашифрованные файлы по email) ---
    patient_data_dir: str = os.environ.get("PATIENT_DATA_DIR", "patient_data")
    # Fernet key (urlsafe base64, 32 bytes). Generate: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
    patient_encryption_key: str | None = os.environ.get("PATIENT_ENCRYPTION_KEY") or None

    # Цены за токены, USD за 1M (Vertex AI global, июнь 2026).
    # 2.5-flash: 0.30/2.50; 3.5-flash: 1.50/9.00.
    price_simple_in: float = float(os.environ.get("PRICE_SIMPLE_IN", "0.30"))
    price_simple_out: float = float(os.environ.get("PRICE_SIMPLE_OUT", "2.50"))
    price_complex_in: float = float(os.environ.get("PRICE_COMPLEX_IN", "1.50"))
    price_complex_out: float = float(os.environ.get("PRICE_COMPLEX_OUT", "9.00"))

    def model_for(self, complexity: str) -> str:
        """Имя модели по уровню сложности запроса."""
        return self.gemini_model_complex if complexity == "complex" else self.gemini_model_simple

    def cost_usd(self, model_name: str, input_tokens: int, output_tokens: int) -> float:
        """Стоимость запроса по числу токенов."""
        if model_name == self.gemini_model_complex:
            p_in, p_out = self.price_complex_in, self.price_complex_out
        else:
            p_in, p_out = self.price_simple_in, self.price_simple_out
        return input_tokens / 1_000_000 * p_in + output_tokens / 1_000_000 * p_out


settings = Settings()
