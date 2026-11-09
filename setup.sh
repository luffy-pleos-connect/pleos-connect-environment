#!/usr/bin/env bash
# Pleos Connect 개발 환경 대화형 설치 스크립트 (macOS 전용)
# 문서: https://document.pleos.ai/docs/pleos-only/getting-started
#
# 사용법:
#   ./setup.sh          # 단계별로 물어보며 설치
#   ./setup.sh --yes    # 모든 질문에 기본값으로 진행 (Pleos 라이선스 동의 포함 주의)
#
# 여러 번 실행해도 안전합니다. 이미 끝난 단계는 감지해서 건너뜁니다.

set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(cd "$(dirname "$0")" && pwd)/scripts/lib.sh"

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage ;;
    *) die "알 수 없는 옵션: $a (--help 참고)" ;;
  esac
done

TOTAL=10

# =====================================================================
step "1/$TOTAL" "사전 점검"
# =====================================================================
[ "$(uname -s)" = "Darwin" ] || die "이 스크립트는 macOS 전용입니다."
info "macOS $(sw_vers -productVersion) / $(arch)"
if [ "$(arch)" = "arm64" ]; then
  info "Apple Silicon → Pleos 이미지: arm64 (${PLEOS_SYSIMG_PKG_ARM64})"
else
  warn "Intel Mac → Pleos 이미지: x86_64 (${PLEOS_SYSIMG_PKG_X86_64})"
  warn "문서는 Mac 에 arm64 이미지를 안내하지만, Intel Mac 에서는 x86_64 이미지를 사용합니다."
fi

free_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
if [ "${free_gb:-0}" -lt 20 ]; then
  warn "홈 디스크 여유 공간이 ${free_gb}GB 입니다. Android Studio + SDK + Pleos 이미지(약 4.7GB, 압축 해제 시 더 큼)에 20GB 이상을 권장합니다."
  ask_yn "그래도 계속할까요?" N || exit 1
else
  ok "디스크 여유 공간 ${free_gb}GB"
fi

if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools 가 없습니다 (git, curl 등에 필요)."
  if ask_yn "지금 설치 창을 띄울까요?"; then
    xcode-select --install || true
    pause "설치 창에서 설치를 완료한 뒤 Enter 를 누르세요..."
    xcode-select -p >/dev/null 2>&1 || die "Command Line Tools 설치가 확인되지 않습니다. 설치 후 다시 실행하세요."
  else
    die "Command Line Tools 가 필요합니다."
  fi
fi
ok "Xcode Command Line Tools"

# =====================================================================
step "2/$TOTAL" "Homebrew"
# =====================================================================
if load_brew; then
  ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"
else
  info "Homebrew 가 없습니다. JDK / Android Studio 설치에 사용합니다."
  if ask_yn "Homebrew 를 설치할까요? (관리자 비밀번호를 물어볼 수 있습니다)"; then
    NONINTERACTIVE="$ASSUME_YES" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew || die "Homebrew 설치 후에도 brew 를 찾을 수 없습니다."
    ok "Homebrew 설치 완료"
  else
    die "Homebrew 없이 진행할 수 없습니다. https://brew.sh 참고 후 다시 실행하세요."
  fi
fi

# =====================================================================
step "3/$TOTAL" "JDK ${JDK_MAJOR}"
# =====================================================================
JAVA_HOME_FOUND="$(find_java_home)"
if [ -n "$JAVA_HOME_FOUND" ]; then
  ok "JDK ${JDK_MAJOR}: $JAVA_HOME_FOUND"
else
  info "JDK ${JDK_MAJOR} 이 없습니다. 터미널에서 Gradle 빌드(./gradlew)를 하려면 필요합니다."
  if ask_yn "Homebrew 로 ${JDK_BREW_CASK} 를 설치할까요?"; then
    brew install --cask "$JDK_BREW_CASK"
    JAVA_HOME_FOUND="$(find_java_home)"
    [ -n "$JAVA_HOME_FOUND" ] || die "JDK 설치 후에도 java_home 에서 찾을 수 없습니다."
    ok "JDK ${JDK_MAJOR}: $JAVA_HOME_FOUND"
  else
    warn "JDK 를 건너뜁니다. 이후 sdkmanager / 샘플 빌드 단계가 실패할 수 있습니다."
  fi
fi
[ -n "$JAVA_HOME_FOUND" ] && export JAVA_HOME="$JAVA_HOME_FOUND"

# =====================================================================
step "4/$TOTAL" "Android Studio"
# =====================================================================
STUDIO_APP="/Applications/Android Studio.app"
if [ -d "$STUDIO_APP" ]; then
  ok "Android Studio 설치됨 ($(defaults read "$STUDIO_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '?'))"
  dim "  문서 권장: 최신 버전. Android Studio > Check for Updates 로 업데이트하세요."
else
  if ask_yn "Android Studio(최신)를 Homebrew 로 설치할까요?"; then
    brew install --cask android-studio
    ok "Android Studio 설치 완료"
  else
    warn "Android Studio 를 건너뜁니다. https://developer.android.com/studio 에서 직접 설치하세요."
  fi
fi

# =====================================================================
step "5/$TOTAL" "Android SDK 위치 & command-line tools"
# =====================================================================
ANDROID_HOME="$(ask "Android SDK 경로" "$(default_android_home)")"
ANDROID_HOME="${ANDROID_HOME/#\~/$HOME}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
mkdir -p "$ANDROID_HOME"
load_android_env

if [ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  ok "cmdline-tools 설치됨"
else
  info "sdkmanager / avdmanager 를 쓰기 위해 Android command-line tools 를 설치합니다."
  build="$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml 2>/dev/null \
    | grep -oE 'commandlinetools-mac-[0-9]+_latest\.zip' | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  build="${build:-$CMDLINE_TOOLS_FALLBACK_BUILD}"
  url="https://dl.google.com/android/repository/commandlinetools-mac-${build}_latest.zip"
  tmp="$(mktemp -d)"
  info "다운로드: $url"
  curl -fL --progress-bar -o "$tmp/cmdline-tools.zip" "$url"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
  ok "cmdline-tools 설치 완료 (build $build)"
fi

# =====================================================================
step "6/$TOTAL" "셸 환경 변수 (ANDROID_HOME, PATH, JAVA_HOME)"
# =====================================================================
PROFILE="$(shell_profile)"
MARK_BEGIN="# >>> pleos-connect-environment >>>"
MARK_END="# <<< pleos-connect-environment <<<"
block="$MARK_BEGIN
export ANDROID_HOME=\"$ANDROID_HOME\"
export ANDROID_SDK_ROOT=\"\$ANDROID_HOME\"
export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH\""
if ask_yn "JAVA_HOME 도 JDK ${JDK_MAJOR} 로 고정할까요? (다른 JDK 를 쓰는 프로젝트가 있으면 n)"; then
  block="$block
export JAVA_HOME=\"\$(/usr/libexec/java_home -v ${JDK_MAJOR} 2>/dev/null)\""
fi
block="$block
$MARK_END"

touch "$PROFILE"
if grep -qF "$MARK_BEGIN" "$PROFILE"; then
  existing="$(sed -n "/$MARK_BEGIN/,/$MARK_END/p" "$PROFILE")"
  if [ "$existing" = "$block" ]; then
    ok "$PROFILE 설정이 이미 최신입니다."
  elif ask_yn "$PROFILE 의 기존 pleos 설정 블록을 갱신할까요?"; then
    cp "$PROFILE" "$PROFILE.pleos-backup"
    sed -i '' "/$MARK_BEGIN/,/$MARK_END/d" "$PROFILE"
    printf '\n%s\n' "$block" >> "$PROFILE"
    ok "갱신 완료 (백업: $PROFILE.pleos-backup)"
  fi
else
  echo "$block" | sed 's/^/    /'
  if ask_yn "위 내용을 $PROFILE 에 추가할까요?"; then
    printf '\n%s\n' "$block" >> "$PROFILE"
    ok "$PROFILE 에 추가했습니다. 새 터미널부터 적용됩니다."
  else
    warn "건너뜀. 직접 PATH 를 설정해야 adb / emulator 명령을 쓸 수 있습니다."
  fi
fi

# =====================================================================
step "7/$TOTAL" "Pleos Connect System Image 저장소 등록"
# =====================================================================
# Android Studio 의 SDK Manager > SDK Update Sites 에 저장소를 추가하는 것과 동일합니다.
# Studio 와 sdkmanager 모두 ~/.android/repositories.cfg 를 읽습니다.
REPO_URL="$(pleos_sysimg_repo)"
AUH="$(android_user_home)"
CFG="$AUH/repositories.cfg"
mkdir -p "$AUH"
if [ -f "$CFG" ] && grep -q 'nexus-playground.pleos.ai/repository/raw-releases/connect-avd' "$CFG"; then
  ok "이미 등록되어 있습니다: $CFG"
else
  count=0
  if [ -f "$CFG" ]; then
    count="$(sed -n 's/^count=\([0-9]*\).*/\1/p' "$CFG" | head -1)"
    count="${count:-0}"
    cp "$CFG" "$CFG.pleos-backup"
    sed -i '' '/^count=/d' "$CFG"
  else
    echo "### User Sources for Android SDK Manager" > "$CFG"
  fi
  idx="$(printf '%02d' "$count")"
  {
    echo "disp${idx}=${PLEOS_SYSIMG_REPO_NAME}"
    echo "enabled${idx}=true"
    echo "src${idx}=$(printf '%s' "$REPO_URL" | sed 's/:/\\:/g')"
    echo "count=$((count + 1))"
  } >> "$CFG"
  ok "등록 완료: ${PLEOS_SYSIMG_REPO_NAME} → $REPO_URL"
fi

# =====================================================================
step "8/$TOTAL" "SDK 패키지 설치 (API ${ANDROID_API}, emulator, Pleos 이미지)"
# =====================================================================
SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
[ -n "${JAVA_HOME:-}" ] || die "sdkmanager 실행에 JDK 가 필요합니다. 3단계에서 JDK 를 설치하세요."

info "Google Android SDK 라이선스에 동의해야 패키지를 설치할 수 있습니다."
if ask_yn "Android SDK 라이선스에 모두 동의할까요? (내용은 'sdkmanager --licenses' 로 확인 가능)"; then
  yes | "$SDKM" --sdk_root="$ANDROID_HOME" --licenses >/dev/null 2>&1 || true
  ok "라이선스 동의 완료"
fi

BASE_PKGS="platform-tools emulator platforms;android-${ANDROID_API} build-tools;${ANDROID_BUILD_TOOLS}"
info "기본 패키지: $BASE_PKGS"
# shellcheck disable=SC2086
"$SDKM" --sdk_root="$ANDROID_HOME" $BASE_PKGS
ok "기본 패키지 설치 완료"

SYSIMG_PKG="$(pleos_sysimg_pkg)"
SYSIMG_DIR="$ANDROID_HOME/$(echo "$SYSIMG_PKG" | tr ';' '/')"
if [ -f "$SYSIMG_DIR/package.xml" ] && grep -q "$PLEOS_EMULATOR_VERSION" "$SYSIMG_DIR/package.xml" 2>/dev/null; then
  ok "Pleos 이미지 설치됨: $SYSIMG_PKG"
else
  if [ -d "$SYSIMG_DIR" ]; then
    warn "이전 버전 Pleos 이미지가 있습니다. 문서 안내대로 삭제 후 새로 설치합니다."
    "$SDKM" --sdk_root="$ANDROID_HOME" --uninstall "$SYSIMG_PKG" || rm -rf "$SYSIMG_DIR"
  fi
  info "Pleos Connect v${PLEOS_EMULATOR_VERSION} 이미지는 약 4.7GB 입니다."
  info "설치 중 42dot 'Pleos Connect SDK License Agreement' 동의를 묻습니다. 내용을 확인 후 y 를 입력하세요."
  if ask_yn "지금 다운로드/설치할까요?"; then
    if [ "$ASSUME_YES" = "1" ]; then
      yes | "$SDKM" --sdk_root="$ANDROID_HOME" "$SYSIMG_PKG"
    else
      "$SDKM" --sdk_root="$ANDROID_HOME" "$SYSIMG_PKG"
    fi
    [ -d "$SYSIMG_DIR" ] || die "Pleos 이미지 설치를 확인할 수 없습니다: $SYSIMG_DIR"
    ok "Pleos 이미지 설치 완료"
  else
    warn "Pleos 이미지 설치를 건너뜁니다. AVD 생성도 건너뜁니다."
  fi
fi

# =====================================================================
step "9/$TOTAL" "AVD 생성 (${AVD_NAME})"
# =====================================================================
AVDM="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
AVD_DIR="$AUH/avd/${AVD_NAME}.avd"

set_ini() { # set_ini file key value
  local f="$1" k="$2" v="$3"
  sed -i '' "/^${k//./\\.}[[:space:]]*=/d" "$f"
  echo "${k}=${v}" >> "$f"
}

if [ ! -d "$SYSIMG_DIR" ]; then
  warn "Pleos 이미지가 없어 건너뜁니다."
else
  create=1
  if [ -d "$AVD_DIR" ]; then
    if ask_yn "AVD '${AVD_NAME}' 가 이미 있습니다. 다시 만들까요? (기존 데이터 삭제)" N; then
      "$AVDM" delete avd -n "$AVD_NAME" || true
    else
      create=0; ok "기존 AVD 유지"
    fi
  fi
  if [ "$create" = "1" ]; then
    echo "no" | "$AVDM" create avd -n "$AVD_NAME" -k "$SYSIMG_PKG"
    ok "AVD 생성 완료"
  fi
  # 문서 권장 설정: Cold boot, RAM 4GB, Graphics Hardware
  CFG_INI="$AVD_DIR/config.ini"
  if [ -f "$CFG_INI" ]; then
    set_ini "$CFG_INI" hw.ramSize "$AVD_RAM_MB"
    set_ini "$CFG_INI" fastboot.forceColdBoot yes
    set_ini "$CFG_INI" fastboot.forceFastBoot no
    set_ini "$CFG_INI" hw.gpu.enabled yes
    set_ini "$CFG_INI" hw.gpu.mode host
    set_ini "$CFG_INI" hw.keyboard yes
    ok "AVD 설정 적용: RAM ${AVD_RAM_MB}MB, Cold boot, GPU host"
  else
    warn "config.ini 를 찾지 못했습니다: $CFG_INI"
  fi
fi

# =====================================================================
step "10/$TOTAL" "Pleos 계정 / 프로젝트 & 샘플 빌드 확인"
# =====================================================================
cat <<EOF
  Pleos Playground 에서 다음을 진행해야 합니다 (웹에서 수동):
    1) ${PLEOS_DEVELOPERS_URL} 회원가입 / 로그인
    2) Workspace > My Project > 프로젝트 생성
    3) 사이드바 SDK 메뉴에서 필요한 SDK 사용 신청
       - Vehicle State, NaviHelper: 신청 없이 사용 가능
EOF
if ask_yn "브라우저에서 Pleos Playground 를 열까요?" N; then
  open "$PLEOS_DEVELOPERS_URL" || true
fi

SAMPLE="$REPO_ROOT/sample"
printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$SAMPLE/local.properties"
if ask_yn "샘플 앱을 빌드해서 Vehicle SDK ${PLEOS_VEHICLE_SDK_VERSION} 의존성까지 확인할까요?"; then
  if (cd "$SAMPLE" && ./gradlew --no-daemon -q :app:assembleDebug); then
    ok "샘플 빌드 성공: sample/app/build/outputs/apk/debug/app-debug.apk"
  else
    err "샘플 빌드 실패. 위 로그를 확인하세요."
  fi
fi

# =====================================================================
printf '\n%s\n' "${C_BOLD}${C_GREEN}설치 완료!${C_RESET}"
cat <<EOF

다음 단계:
  • 새 터미널을 열거나:   source $PROFILE
  • 환경 점검:            ./scripts/doctor.sh
  • 에뮬레이터 실행:       ./scripts/emulator.sh          (샘플 설치까지: --install)
  • Android Studio 첫 실행 시 SDK 경로로 ${ANDROID_HOME} 를 선택하세요.
  • 샘플 프로젝트:         Android Studio > Open > $(basename "$REPO_ROOT")/sample
EOF
