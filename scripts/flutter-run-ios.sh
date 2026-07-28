#!/usr/bin/env bash
set -euo pipefail

DEVICE="${IOS_DEVICE_ID:-iPhone 17}"
DART_DEFINE_FILE="${PHA_DART_DEFINE_FILE:-dart_define.json}"
mkdir -p .just

if [[ ! -f "$DART_DEFINE_FILE" ]]; then
  echo "ERROR: $DART_DEFINE_FILE not found."
  echo "       cp dart_define.example.json dart_define.json"
  echo "       then set PHA_API_KEY to match backend API_KEY"
  exit 1
fi

echo "-> flutter run on ${DEVICE}..."
echo "   dart defines: ${DART_DEFINE_FILE}"
echo "   hot reload: just reload  |  hot restart: just restart  |  in this terminal: r / R"

flutter run -d "$DEVICE" --dart-define-from-file="$DART_DEFINE_FILE" "$@" 2>&1 | tee .just/flutter-run.log | while IFS= read -r line; do
  if [[ "$line" =~ (http://127\.0\.0\.1:[0-9]+/[^[:space:]]+) ]]; then
    if [[ "$line" == *"Dart VM Service"* ]]; then
      echo "${BASH_REMATCH[1]}" > .just/vm_service_url
    fi
  fi
done
