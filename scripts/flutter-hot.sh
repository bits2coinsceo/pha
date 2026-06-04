#!/usr/bin/env bash
# Hot reload (r) or hot restart (R) for the active `just run` session.
set -euo pipefail

export DEVICE="${IOS_DEVICE_ID:-iPhone 17}"
export KEY="${1:-r}"

if [[ "$KEY" != "r" && "$KEY" != "R" ]]; then
  echo "Usage: $0 [r|R]" >&2
  exit 1
fi

if ! pgrep -f "flutter_tools.snapshot run" >/dev/null 2>&1; then
  echo "No active 'just run'. Start: just run" >&2
  exit 1
fi

label=$([[ "$KEY" == "R" ]] && echo "restart" || echo "reload")

VM_URL=""
if [[ -f .just/vm_service_url ]]; then
  VM_URL=$(tr -d '[:space:]' < .just/vm_service_url)
fi

if [[ -z "$VM_URL" ]]; then
  RUN_PID=$(pgrep -f "flutter_tools.snapshot run" | head -1)
  if [[ -n "$RUN_PID" ]]; then
    while read -r pid; do
      [[ -z "$pid" ]] && continue
      args=$(ps -p "$pid" -o args= 2>/dev/null || true)
      [[ "$args" != *"development-service"* ]] && continue
      [[ "$args" != *"--vm-service-uri="* ]] && continue
      p=$pid
      found=
      for _ in $(seq 1 12); do
        if [[ "$p" == "$RUN_PID" ]]; then found=1; break; fi
        p=$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ' || echo "")
        [[ -z "$p" || "$p" == "0" || "$p" == "1" ]] && break
      done
      if [[ -n "$found" ]]; then
        VM_URL=$(sed -n 's/.*--vm-service-uri=\([^ ]*\).*/\1/p' <<<"$args")
        break
      fi
    done < <(pgrep -f "development-service" 2>/dev/null || true)
  fi
fi

if [[ -z "$VM_URL" ]]; then
  echo "Could not find VM service URL." >&2
  echo "Press '$KEY' in the terminal where 'just run' is running." >&2
  exit 1
fi

echo "-> Hot $label on ${DEVICE}..."

bundle_id="${PHA_BUNDLE_ID:-com.pha.phaFlutter}"

# Hot restart (R): relaunch on simulator — works when `flutter attach` piping times out.
if [[ "$KEY" == "R" ]] && xcrun simctl terminate "$DEVICE" "$bundle_id" 2>/dev/null; then
  sleep 0.4
  if xcrun simctl launch "$DEVICE" "$bundle_id" >/dev/null 2>&1; then
    echo "OK: app restarted on $DEVICE"
    exit 0
  fi
fi

export KEY DEVICE VM_URL
attach_cmd='( sleep 3; printf "%s\nq\n" "$KEY" ) | flutter attach -d "$DEVICE" --debug-url="$VM_URL"'

if command -v perl >/dev/null 2>&1; then
  perl -e 'alarm 25; exec @ARGV' bash -c "$attach_cmd" || {
    echo "Timed out. Press '$KEY' in the 'just run' terminal." >&2
    exit 1
  }
else
  bash -c "$attach_cmd" || {
    echo "Failed. Press '$KEY' in the 'just run' terminal." >&2
    exit 1
  }
fi

echo "OK: hot $label sent"
