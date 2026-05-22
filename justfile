# pha_flutter — just --list
# brew install just

set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

flutter := "flutter"
bundle_id := "com.pha.phaFlutter"
ios_device := env_var_or_default("IOS_DEVICE_ID", "iPhone 15 Pro")
simulator_app := "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"

default:
    @just --list

devices:
    {{flutter}} devices

# Поднять iPhone-симулятор (быстро, без долгого цикла flutter devices)
sim:
    @echo "→ Boot {{ios_device}}…"
    xcrun simctl boot "{{ios_device}}" 2>/dev/null || true
    xcrun simctl bootstatus "{{ios_device}}" -b 2>/dev/null || true
    @echo "→ Open Simulator…"
    open "{{simulator_app}}" 2>/dev/null || true
    @echo "✓ Simulator ready (check the Simulator window)"

run: sim
    @echo "→ flutter run on iPhone…"
    {{flutter}} run -d "{{ios_device}}"

run-ios: run

run-macos:
    {{flutter}} run -d macos

clean:
    @echo "→ flutter clean…"
    {{flutter}} clean
    @echo "→ pub get…"
    {{flutter}} pub get
    @echo "→ pod install…"
    cd ios && pod install
    @echo "✓ clean done"

purge:
    @echo "→ Uninstall app from simulator (clears saved onboarding too)…"
    xcrun simctl uninstall "{{ios_device}}" {{bundle_id}} 2>/dev/null || true
    xcrun simctl uninstall booted {{bundle_id}} 2>/dev/null || true
    @echo "✓ app removed"

# Сброс данных + запуск (без flutter clean — ~1–3 мин)
reset: sim purge
    @echo "→ flutter run…"
    {{flutter}} run -d "{{ios_device}}"

reset-quick: reset

# Полный сброс с пересборкой (долго — 5–15 мин, будет тишина на clean)
reset-full: sim clean purge
    @echo "→ flutter run…"
    {{flutter}} run -d "{{ios_device}}"

reset-ios: reset
