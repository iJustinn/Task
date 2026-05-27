#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Task"
PROJECT_NAME="task.xcodeproj"
SCHEME_NAME="Task"
BUNDLE_ID="com.ijustin.task"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/task-mac-run}"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug-maccatalyst/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

stop_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  pkill -f "/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet \
    build
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

stop_existing_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
