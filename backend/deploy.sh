#!/usr/bin/env bash
#
# Деплой PHA backend на удалённый хост по SSH.
#
#   ./deploy.sh user@host [remote_dir]
#
# Что делает:
#   1. Синхронизирует исходники на сервер (rsync, без секретов и мусора).
#   2. Поднимает контейнер через docker compose.
#
# ВАЖНО: ключ сервис-аккаунта (secrets/sa.json) и .env намеренно НЕ копируются
# через rsync. Перед первым деплоем скопируй их на сервер отдельно и безопасно:
#
#   ssh user@host 'mkdir -p ~/pha-backend/secrets'
#   scp ./secrets/sa.json user@host:~/pha-backend/secrets/sa.json
#   scp ./.env           user@host:~/pha-backend/.env
#
set -euo pipefail

HOST="${1:?Usage: ./deploy.sh user@host [remote_dir]}"
REMOTE_DIR="${2:-pha-backend}"

echo ">> Синхронизация исходников на ${HOST}:${REMOTE_DIR}"
rsync -avz --delete \
  --exclude '.git' \
  --exclude '.venv' \
  --exclude 'venv' \
  --exclude '__pycache__' \
  --exclude 'secrets' \
  --exclude '.env' \
  ./ "${HOST}:${REMOTE_DIR}/"

echo ">> Сборка и запуск контейнера на ${HOST}"
ssh "${HOST}" "cd ${REMOTE_DIR} && docker compose up -d --build && docker compose ps"

echo ">> Готово. Проверка здоровья:"
ssh "${HOST}" "curl -fsS http://localhost:8080/health || echo 'health-check не прошёл'"
