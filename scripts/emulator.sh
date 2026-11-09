#!/usr/bin/env bash
# Pleos Connect 에뮬레이터 실행 (Cold boot) 및 부팅 대기.
# 사용법:
#   ./scripts/emulator.sh            # 에뮬레이터 실행 후 부팅 완료까지 대기
#   ./scripts/emulator.sh --install  # 부팅 후 sample 앱 빌드/설치/실행

set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_android_env

INSTALL=0
for a in "$@"; do
  case "$a" in
    --install) INSTALL=1 ;;
    -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "알 수 없는 옵션: $a" ;;
  esac
done

EMU="$ANDROID_HOME/emulator/emulator"
ADB="$ANDROID_HOME/platform-tools/adb"
[ -x "$EMU" ] || die "emulator 가 없습니다. ./setup.sh 를 먼저 실행하세요."
"$EMU" -list-avds | grep -qx "$AVD_NAME" || die "AVD '$AVD_NAME' 가 없습니다. ./setup.sh 를 먼저 실행하세요."

if "$ADB" devices | grep -q '^emulator-'; then
  info "이미 실행 중인 에뮬레이터가 있습니다."
else
  mkdir -p "$REPO_ROOT/.setup-logs"
  LOG="$REPO_ROOT/.setup-logs/emulator.log"
  info "에뮬레이터 실행: $AVD_NAME (Cold boot) — 로그: $LOG"
  nohup "$EMU" -avd "$AVD_NAME" -no-snapshot-load >"$LOG" 2>&1 &
fi

info "부팅 대기 중... (처음에는 수 분 걸릴 수 있습니다)"
"$ADB" wait-for-device
for _ in $(seq 1 180); do
  if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    ok "부팅 완료"; break
  fi
  sleep 2
done
[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] || die "부팅 대기 시간 초과"

if [ "$INSTALL" = "1" ]; then
  printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$REPO_ROOT/sample/local.properties"
  (cd "$REPO_ROOT/sample" && ./gradlew -q :app:installDebug)
  "$ADB" shell am start -n ai.pleos.sample.hello/.MainActivity
  ok "샘플 앱 실행. 화면에 운전석 문 위치 결과가 표시됩니다."
fi
