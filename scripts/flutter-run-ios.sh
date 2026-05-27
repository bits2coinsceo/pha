#!/usr/bin/env bash
set -euo pipefail

DEVICE="${IOS_DEVICE_ID:-iPhone 17}"
mkdir -p .just

echo "-> flutter run on ${DEVICE}..."
echo "   hot reload: just reload  |  hot restart: just restart  |  in this terminal: r / R"

flutter run -d "$DEVICE" 2>&1 | tee .just/flutter-run.log | while IFS= read -r line; do
  if [[ "$line" =~ (http://127\.0\.0\.1:[0-9]+/[^[:space:]]+) ]]; then
    if [[ "$line" == *"Dart VM Service"* ]]; then
      echo "${BASH_REMATCH[1]}" > .just/vm_service_url
    fi
  fi
done
