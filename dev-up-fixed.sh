#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$ROOT_DIR/frontend"

# You can override these per-run:
# SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_STORAGE_BUCKET=... ./dev-up.sh
SUPABASE_URL="${SUPABASE_URL:-https://ptsxvlufpguyncagotqw.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0c3h2bHVmcGd1eW5jYWdvdHF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyODA4NjIsImV4cCI6MjA5MTg1Njg2Mn0.ajmIz45Sf1fwweYueD9ydJqsU_iXPN-Tn1nyDCJ0-g8}"
SUPABASE_STORAGE_BUCKET="${SUPABASE_STORAGE_BUCKET:-voice-memos}"
AVD_NAME="${AVD_NAME:-Pixel_7_Pro}"
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-buildvox}"

# Ensure adb is on PATH (Flutter needs a live Android device at flutter-run time)
if [[ -z "${ANDROID_HOME:-}" ]] && [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
if [[ -n "${ANDROID_HOME:-}" ]]; then
  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
fi

for cmd in flutter firebase; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

ensure_port_available() {
  local port="$1"
  local pids
  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  echo ">> Port $port is in use; stopping stale listener(s): $pids"
  for pid in $pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  sleep 1

  pids="$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "Port $port is still busy after cleanup (pid(s): $pids)."
    echo "Stop those processes manually and rerun ./dev-up.sh."
    exit 1
  fi
}

# First column matching emulator-NNNN in `flutter devices` output.
# Do not fail the script: `flutter devices` can exit non-zero under set -o pipefail.
get_android_emulator_id() {
  flutter devices 2>/dev/null \
    | awk '/emulator-[0-9]+/ { for (i = 1; i <= NF; i++) if ($i ~ /^emulator-[0-9]+$/) { print $i; exit } }' \
    || true
}

cleanup() {
  if [[ -n "${FIREBASE_EMULATOR_PID:-}" ]] && kill -0 "$FIREBASE_EMULATOR_PID" >/dev/null 2>&1; then
    kill "$FIREBASE_EMULATOR_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo ">> Ensuring Android emulator is running..."
adb start-server >/dev/null 2>&1 || true

DEVICE_ID="$(get_android_emulator_id)"
if [[ -z "$DEVICE_ID" ]]; then
  echo "   Launching AVD: $AVD_NAME"
  flutter emulators --launch "$AVD_NAME" >/dev/null 2>&1 || true
  for _ in {1..60}; do
    sleep 2
    DEVICE_ID="$(get_android_emulator_id)"
    if [[ -n "$DEVICE_ID" ]]; then
      break
    fi
  done
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No Android emulator detected. Start one manually and rerun."
  exit 1
fi
echo ">> Using device: $DEVICE_ID"

echo ">> Starting Firebase Functions emulator (API only; auth + DB are Supabase)..."
# Free known ports from stale previous runs (Functions UI/hub/logging sometimes collide).
for port in 4000 4400 4500 5001; do
  ensure_port_available "$port"
done

(
  cd "$ROOT_DIR"
  firebase use "$FIREBASE_PROJECT_ID" >/dev/null 2>&1 || true
  firebase emulators:start --only functions
) &
FIREBASE_EMULATOR_PID=$!

# Wait for functions emulator HTTP endpoint
for _ in {1..45}; do
  if curl -sf "http://127.0.0.1:5001/" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# Re-resolve device: emulator can drop from adb between first check and flutter run
echo ">> Re-checking Android device before flutter run..."
adb start-server >/dev/null 2>&1 || true
DEVICE_ID=""
for _ in {1..45}; do
  DEVICE_ID="$(get_android_emulator_id)"
  if [[ -n "$DEVICE_ID" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "$DEVICE_ID" ]]; then
  echo "Android emulator disappeared from adb/flutter. Try:"
  echo "  flutter emulators --launch $AVD_NAME"
  echo "  adb devices"
  exit 1
fi
echo ">> Running on: $DEVICE_ID"

echo ">> Running Flutter app (Supabase auth/data + Functions emulator for API)..."
cd "$FRONTEND_DIR"
flutter run -d "$DEVICE_ID" \
  --device-timeout 120 \
  --dart-define="USE_FIREBASE_EMULATOR=true" \
  --dart-define="FIREBASE_EMULATOR_HOST=10.0.2.2" \
  --dart-define="FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --dart-define="SUPABASE_STORAGE_BUCKET=$SUPABASE_STORAGE_BUCKET"
