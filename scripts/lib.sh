#!/usr/bin/env bash
# 공통 헬퍼. macOS 기본 bash 3.2 호환으로 작성 (연관 배열, ${x,,} 등 사용 금지).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../config/versions.env
. "$REPO_ROOT/config/versions.env"

# ---------- 출력 ----------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_CYAN=
fi

info()  { printf '%s\n' "${C_BLUE}ℹ${C_RESET} $*"; }
ok()    { printf '%s\n' "${C_GREEN}✔${C_RESET} $*"; }
warn()  { printf '%s\n' "${C_YELLOW}⚠${C_RESET} $*" >&2; }
err()   { printf '%s\n' "${C_RED}✖${C_RESET} $*" >&2; }
die()   { err "$*"; exit 1; }
step()  { printf '\n%s\n' "${C_BOLD}${C_CYAN}━━ [$1] $2${C_RESET}"; }
dim()   { printf '%s\n' "${C_DIM}$*${C_RESET}"; }

# ---------- 대화형 입력 ----------
# ASSUME_YES=1 이면 모든 질문에 기본값으로 응답 (CI/비대화형용)
ASSUME_YES="${ASSUME_YES:-0}"

# ask_yn "질문" [Y|N]  -> 0(yes) / 1(no)
ask_yn() {
  local q="$1" def="${2:-Y}" hint ans
  if [ "$def" = "Y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then
    dim "  $q $hint → $def (자동)"
    [ "$def" = "Y" ]; return
  fi
  while true; do
    printf '%s ' "${C_BOLD}?${C_RESET} $q $hint"
    read -r ans || ans=""
    [ -z "$ans" ] && ans="$def"
    case "$ans" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
      *) echo "  y 또는 n 으로 입력해 주세요." ;;
    esac
  done
}

# ask "질문" "기본값" -> stdout 으로 결과
ask() {
  local q="$1" def="${2:-}" ans
  if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then
    printf '%s' "$def"; return
  fi
  printf '%s ' "${C_BOLD}?${C_RESET} $q ${C_DIM}(${def})${C_RESET}" >&2
  read -r ans || ans=""
  printf '%s' "${ans:-$def}"
}

pause() {
  if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then return; fi
  printf '%s' "${C_DIM}  ${1:-계속하려면 Enter 를 누르세요...}${C_RESET}"
  read -r _ || true
}

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 환경 값 ----------
arch() { uname -m; }   # arm64 | x86_64

pleos_abi() {
  if [ "$(arch)" = "arm64" ]; then echo "arm64-v8a"; else echo "x86_64"; fi
}
pleos_sysimg_pkg() {
  if [ "$(arch)" = "arm64" ]; then echo "$PLEOS_SYSIMG_PKG_ARM64"; else echo "$PLEOS_SYSIMG_PKG_X86_64"; fi
}
pleos_sysimg_repo() {
  if [ "$(arch)" = "arm64" ]; then echo "$PLEOS_SYSIMG_REPO_ARM64"; else echo "$PLEOS_SYSIMG_REPO_X86_64"; fi
}

default_android_home() {
  if [ -n "${ANDROID_HOME:-}" ]; then echo "$ANDROID_HOME"
  elif [ -n "${ANDROID_SDK_ROOT:-}" ]; then echo "$ANDROID_SDK_ROOT"
  else echo "$HOME/Library/Android/sdk"; fi
}

# ~/.android (ANDROID_USER_HOME 로 재정의 가능)
android_user_home() { echo "${ANDROID_USER_HOME:-$HOME/.android}"; }

find_java_home() {
  /usr/libexec/java_home -v "$JDK_MAJOR" 2>/dev/null || true
}

# 셸 프로필 파일 선택 (zsh 기본)
shell_profile() {
  case "${SHELL:-/bin/zsh}" in
    */bash) echo "$HOME/.bash_profile" ;;
    *)      echo "$HOME/.zshrc" ;;
  esac
}

# Homebrew 경로를 현재 셸에 로드
load_brew() {
  if have brew; then return 0; fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
  done
  return 1
}

# Android 관련 PATH 를 현재 셸에 로드
load_android_env() {
  export ANDROID_HOME="${ANDROID_HOME:-$(default_android_home)}"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
  local jh; jh="$(find_java_home)"
  if [ -n "$jh" ]; then export JAVA_HOME="$jh"; fi
}
