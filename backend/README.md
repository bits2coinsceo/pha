# PHA Backend

Python API (FastAPI) поверх **Vertex AI Gemini**. Отвечает на запросы мобильного
приложения и анализирует медицинские данные (текст + PDF снимков КТ/МРТ).

## Эндпоинты

| Метод | Путь       | Описание                                            |
|-------|------------|-----------------------------------------------------|
| GET   | `/health`  | Статус сервиса, активная модель и проект            |
| POST  | `/chat`    | `{ "message": "...", "complexity": "simple\|complex" }` → `{ "reply", "model" }` |
| POST  | `/analyze` | multipart: `text_logs` + файл `pdf` (+ `complexity`) → `{ "analysis", "model" }` |
| —     | `/docs`    | Авто-документация Swagger                            |

Если в окружении задан `API_KEY`, все эндпоинты (кроме `/health`) требуют
заголовок `X-API-Key`.

## Локальный запуск (без Docker)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export GOOGLE_APPLICATION_CREDENTIALS="/абсолютный/путь/к/ключу.json"
cp .env.example .env   # при желании поправь модель/ключ
uvicorn app.main:app --reload --port 8080
```

Проверка:

```bash
curl localhost:8080/health

# чат (user_id обязателен; complexity по умолчанию simple)
curl -X POST localhost:8080/chat -H 'Content-Type: application/json' \
  -d '{"user_id":"user-42","message":"Привет, кто ты?","complexity":"simple"}'

# мед-анализ (по умолчанию complex)
curl -X POST localhost:8080/analyze \
  -F 'user_id=user-42' \
  -F 'text_logs=Гемоглобин 110, давление 150/95' \
  -F 'pdf=@/путь/к/снимку.pdf'

# остаток лимита
curl localhost:8080/usage/user-42
```

## Запуск в Docker

1. Положи ключ сервис-аккаунта в `backend/secrets/sa.json` (каталог в `.gitignore`):

   ```bash
   mkdir -p secrets
   cp "/Users/deveus/Downloads/Telegram Desktop/pha-personal-health-assistant-50d0e32300d8.json" secrets/sa.json
   ```

2. (Опционально) `cp .env.example .env` и задай `API_KEY` / `GEMINI_MODEL`.

3. Старт:

   ```bash
   docker compose up -d --build
   docker compose logs -f
   ```

## Деплой на SSH-хост

```bash
# первый раз — закинуть секреты вручную (rsync их не копирует):
ssh user@host 'mkdir -p ~/pha-backend/secrets'
scp secrets/sa.json user@host:~/pha-backend/secrets/sa.json
scp .env            user@host:~/pha-backend/.env   # если используешь

# деплой:
./deploy.sh user@host
```

`deploy.sh` синхронизирует код и выполняет `docker compose up -d --build` на сервере.

## Безопасность

- **Ключ сервис-аккаунта НЕ коммитится** — он монтируется как volume только для
  чтения через `GOOGLE_APPLICATION_CREDENTIALS`.
- Для прода задай `API_KEY` и проксируй сервис за HTTPS (nginx/Caddy/Cloudflare),
  не выставляй порт 8080 в интернет напрямую.

## Свитчер моделей

Запрос выбирает модель полем `complexity`:

- `simple`  → `GEMINI_MODEL_SIMPLE` (по умолчанию `gemini-2.5-flash`) — быстрые/дешёвые ответы;
- `complex` → `GEMINI_MODEL_COMPLEX` (по умолчанию `gemini-3.5-flash`) — сложные рассуждения, мед-анализ.

`/chat` по умолчанию `simple`, `/analyze` — `complex`. В ответе возвращается поле
`model` — какая модель реально отработала.

## Лимит кредитов на пользователя

Каждый запрос обязан содержать `user_id` (можно ID пользователя из приложения).
Сервер считает стоимость по токенам (`usage_metadata`) и копит её в SQLite по
`user_id`. Лимит — `USER_BUDGET_USD` (по умолчанию `5`). При исчерпании лимита
запрос отклоняется с кодом `402 Payment Required`.

Цены проставлены по официальному прайсу Vertex AI (июнь 2026), USD за 1M токенов:
`gemini-2.5-flash` — $0.30 in / $2.50 out; `gemini-3.5-flash` (региональный
us-central1) — $1.65 / $9.90. Меняются через `PRICE_SIMPLE_IN/OUT` и
`PRICE_COMPLEX_IN/OUT` в `.env`. Учти: кэшированный ввод и batch-режим дешевле —
этот расчёт берёт стандартный тариф, т.е. слегка завышает (лимит сработает раньше).

Проверить остаток: `GET /usage/{user_id}` → `{ "user_id", "spent_usd", "remaining_usd", "limit_usd" }`.
