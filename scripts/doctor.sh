#!/usr/bin/env bash
# Pleos Connect 개발 환경 점검. 아무것도 설치/변경하지 않습니다.
# 사용법: ./scripts/doctor.sh

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

load_brew >/dev/null 2>&1 || true
load_android_env

FAIL=0
check() { # check "이름" 명령...
  local name="$1"; shift
  local out
  if out="$("$@" 2>/dev/null)"; then ok "$name ${C_DIM}${out}${C_RESET}"
  else err "$name"; FAIL=$((FAIL + 1)); fi
}

c_macos()   { [ "$(uname -s)" = Darwin ] && echo "$(sw_vers -productVersion) $(arch)"; }
c_clt()     { xcode-select -p; }
c_brew()    { have brew && brew --version | head -1; }
c_jdk()     { local j; j="$(find_java_home)"; [ -n "$j" ] && echo "$j"; }
c_studio()  { [ -d "/Applications/Android Studio.app" ] && defaults read "/Applications/Android Studio.app/Contents/Info" CFBundleShortVersionString; }
c_sdk()     { [ -d "$ANDROID_HOME" ] && echo "$ANDROID_HOME"; }
c_cmdline() { [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ] && echo ok; }
c_ptools()  { [ -x "$ANDROID_HOME/platform-tools/adb" ] && "$ANDROID_HOME/platform-tools/adb" version | head -1; }
c_emu()     { [ -x "$ANDROID_HOME/emulator/emulator" ] && "$ANDROID_HOME/emulator/emulator" -version 2>/dev/null | head -1; }
c_platform(){ [ -d "$ANDROID_HOME/platforms/android-$ANDROID_API" ] && echo "android-$ANDROID_API"; }
c_bt()      { [ -d "$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS" ] && echo "$ANDROID_BUILD_TOOLS"; }
c_repo()    { grep -q 'nexus-playground.pleos.ai/repository/raw-releases/connect-avd' "$(android_user_home)/repositories.cfg" && echo "$(android_user_home)/repositories.cfg"; }
c_sysimg()  { local d; d="$ANDROID_HOME/$(pleos_sysimg_pkg | tr ';' '/')"; [ -d "$d" ] && pleos_sysimg_pkg; }
c_avd()     { local c="$(android_user_home)/avd/${AVD_NAME}.avd/config.ini"; [ -f "$c" ] && grep -qx "hw.device.name=${AVD_DEVICE_ID}" "$c" && echo "$AVD_NAME ($(sed -n 's/^hw\.lcd\.width=//p' "$c")x$(sed -n 's/^hw\.lcd\.height=//p' "$c"))"; }
c_maven()   { curl -fsS -o /dev/null -w '%{http_code}' "${PLEOS_MAVEN_URL}ai/pleos/playground/Vehicle/${PLEOS_VEHICLE_SDK_VERSION}/Vehicle-${PLEOS_VEHICLE_SDK_VERSION}.pom"; }
c_profile() { grep -q '>>> pleos-connect-environment >>>' "$(shell_profile)" && shell_profile; }

printf '%s\n' "${C_BOLD}Pleos Connect 개발 환경 점검${C_RESET}"
check "macOS"                         c_macos
check "Xcode Command Line Tools"      c_clt
check "Homebrew"                      c_brew
check "JDK ${JDK_MAJOR}"              c_jdk
check "Android Studio"                c_studio
check "Android SDK"                   c_sdk
check "cmdline-tools"                 c_cmdline
check "platform-tools (adb)"          c_ptools
check "emulator"                      c_emu
check "Platform API ${ANDROID_API}"   c_platform
check "build-tools"                   c_bt
check "Pleos SDK Update Site 등록"    c_repo
check "Pleos 시스템 이미지"           c_sysimg
check "AVD"                           c_avd
check "Pleos Maven (Vehicle ${PLEOS_VEHICLE_SDK_VERSION})" c_maven
check "셸 프로필 설정"                c_profile

echo
if [ "$FAIL" -eq 0 ]; then ok "모든 항목 정상"; else warn "${FAIL}개 항목 실패 → ./setup.sh 를 다시 실행하세요."; fi
exit "$FAIL"
