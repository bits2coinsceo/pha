# PHA API — reference for local AI assistants

This file orients any AI/dev working in this repo on the backend API and how the
Flutter app talks to it. Keep it up to date when the API changes.

## TL;DR

- **Backend lives in** [`backend/`](backend/) — Python **FastAPI** wrapping **Vertex AI Gemini**.
- **Deployed on** SSH host `fest` → `http://49.13.66.150:8080` (Docker, `restart: unless-stopped`).
- **App talks to it** via [`lib/api.dart`](lib/api.dart) (`ApiClient.chat` / `ApiClient.analyze`).
- **Auth:** header `X-API-Key: <key>` on every call except `/health`.
- Full backend docs: [`backend/README.md`](backend/README.md).

## Where the API is

| | Value |
|---|---|
| Base URL (prod) | `http://49.13.66.150:8080` |
| Host alias | `fest` (`ssh fest`, root@49.13.66.150) |
| Remote dir | `/root/pha-backend` |
| Runtime | Docker Compose, port `8080`, container `pha-backend` |
| Source | `backend/` in this repo |

> ⚠️ Plain HTTP, no TLS yet. iOS reaches it via an ATS exception in
> `ios/Runner/Info.plist` (`NSAllowsArbitraryLoads`) — **remove once HTTPS is set up**.

## What's in the backend

FastAPI app (`backend/app/`):

- `main.py` — routes, API-key guard, per-user budget guard.
- `vertex.py` — Vertex AI Gemini wrapper (auth via `GOOGLE_APPLICATION_CREDENTIALS`).
- `config.py` — env-driven settings (models, prices, budget).
- `usage.py` — per-`user_id` spend tracking in SQLite.

**Model switcher** — request field `complexity`:
- `simple` → `gemini-1.5-flash` by default
- `complex` → `gemini-1.5-flash` by default

Both paths currently use Gemini 1.5 Flash to reduce photo request rate-limit
failures. Override with `GEMINI_MODEL_SIMPLE` / `GEMINI_MODEL_COMPLEX` only if
the Vertex quota is available.

**Per-user credit limit** — every request carries a `user_id`; cost is computed
from token usage and accumulated in SQLite. Limit `USER_BUDGET_USD` (default `$5`).
Over limit → **HTTP 402**.

**GCP:** project `pha-personal-health-assistant`, service account
`pha-backend@pha-personal-health-assistant.iam.gserviceaccount.com`, role
**Agent Platform user** (`roles/aiplatform.user`), endpoint `GCP_LOCATION=global`
(Gemini 3.x is not available in regional endpoints like `us-central1`).

## Endpoints

### `GET /health`
No auth. Returns status, configured models, project, location, budget.

### `POST /chat` — AI consultation
Auth required. JSON body:
```json
{ "user_id": "u-123", "message": "...", "complexity": "simple" }
```
Response: `{ "reply": "...", "model": "...", "cost_usd": 0.0, "remaining_usd": 4.99 }`

### `POST /analyze` — medical analysis (text + file)
Auth required. `multipart/form-data`:
- `user_id` (required)
- `text_logs` (optional text, e.g. lab values)
- `pdf` (file — PDF or image; field name is literally `pdf`)
- `complexity` (default `complex`)

Response: `{ "analysis": "...", "model": "...", "cost_usd": 0.0, "remaining_usd": 4.99 }`

### `GET /usage/{user_id}`
Auth required. `{ "user_id", "spent_usd", "remaining_usd", "limit_usd" }`

### `GET /patient/exists?email=...`
Auth required. `{ "email", "exists": true|false }` — whether a history file exists.

### `GET /patient/history`
Auth required. Headers:
- `X-Patient-Email` — patient email (normalized lowercase)
- `X-Sync-Token` — SHA256 of `pha-salt::password` (same as app `password_hash`)

Returns full health history JSON (profile + all metric tables). `404` if none, `403` if wrong token.

### `PUT /patient/history`
Auth required. Same headers as GET. Body = full history snapshot (encrypted at rest on server, keyed by email).

### Errors
- `401` — missing/wrong `X-API-Key`.
- `402` — user's credit budget exhausted (surface an upgrade prompt).
- `502` — upstream model error.

## How the Flutter app uses it

- **Config:** [`lib/api.dart`](lib/api.dart) → `ApiConfig.baseUrl` / `ApiConfig.apiKey`,
  both from `--dart-define` (`PHA_API_BASE`, `PHA_API_KEY`).
- **Client:** `ApiClient.chat(...)` and `ApiClient.analyze(...)`.
- **AI Consultation:** `AiConsultationService.reply(userId, message)` in
  [`lib/services.dart`](lib/services.dart) calls `/chat`, with a local keyword
  responder as offline fallback. UI: `AIChatModal` in
  [`lib/modals/quick_action_modals.dart`](lib/modals/quick_action_modals.dart).
- **Upload Analysis:** `UploadAnalysisModal._upload` posts the picked file to
  `/analyze`, stores the returned `analysis` in the `analysis_uploads` table, and
  shows it. Same file.

### Running the app against the backend

The API key is passed at build time so it never lands in git:

```bash
cp dart_define.example.json dart_define.json   # then fill in PHA_API_KEY
flutter run --dart-define-from-file=dart_define.json
```

`dart_define.json` is git-ignored. `PHA_API_KEY` must equal the backend's
`API_KEY` (in `backend/.env`).

> Security note: an API key shipped in a mobile binary is extractable. It's a
> basic gate, not real per-user auth. Long term, move to real user auth/tokens.

## Deploy / operate the backend

```bash
# from backend/ ; secrets (secrets/sa.json, .env) are NOT rsynced — copy once:
ssh fest 'mkdir -p ~/pha-backend/secrets'
scp secrets/sa.json fest:~/pha-backend/secrets/sa.json
scp .env            fest:~/pha-backend/.env
./deploy.sh fest          # rsync code + docker compose up -d --build

# logs / status
ssh fest 'cd ~/pha-backend && docker compose ps && docker compose logs -f'
```

## Known follow-ups

- **HTTPS** — backend is plain HTTP on an IP; add a reverse proxy (Caddy/nginx)
  with TLS + domain, then drop the iOS ATS exception.
- **Deprecated SDK** — `vertexai.generative_models` is deprecated (removal
  ~2026-06-24); migrate `backend/app/vertex.py` to `google-genai`.
- **Single worker** — SQLite usage counter assumes one uvicorn worker; move to
  Postgres/Redis to scale out.
