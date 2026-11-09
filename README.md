# pleos-connect-environment

[Pleos Getting Started](https://document.pleos.ai/docs/pleos-only/getting-started) 문서의 개발 환경을 **macOS 에서 대화형으로 한 번에** 구축하는 스크립트입니다.

## 빠른 시작

```bash
git clone https://github.com/luffy-pleos-connect/pleos-connect-environment.git
cd pleos-connect-environment
./setup.sh
```

각 단계마다 `[Y/n]` 으로 물어보며 진행합니다. 이미 끝난 단계는 감지해서 건너뛰므로 **여러 번 실행해도 안전**합니다.

| 명령 | 설명 |
| --- | --- |
| `./setup.sh` | 대화형 설치 |
| `./setup.sh --yes` | 모든 질문에 기본값으로 응답 (Pleos 라이선스 동의 포함, 주의) |
| `./scripts/doctor.sh` | 설치 상태 점검 (변경 없음) |
| `./scripts/emulator.sh` | Pleos 에뮬레이터 Cold boot 실행 + 부팅 대기 |
| `./scripts/emulator.sh --install` | 부팅 후 샘플 앱 설치/실행 |

## setup.sh 가 하는 일

| 단계 | 내용 | 문서 대응 |
| --- | --- | --- |
| 1 | macOS / CPU(arm64·x86_64) / 디스크 / Xcode CLT 확인 | – |
| 2 | Homebrew 설치 확인 | – |
| 3 | JDK 17 (`temurin@17`) | CLI 빌드용 |
| 4 | Android Studio (`brew --cask android-studio`) | 사전 준비 |
| 5 | Android SDK 경로 선택 (기본 `~/Library/Android/sdk`) + cmdline-tools | 사전 준비 |
| 6 | `~/.zshrc` 에 `ANDROID_HOME`, `PATH`, (선택) `JAVA_HOME` 추가 | – |
| 7 | **SDK Update Site 등록**: `Pleos Connect System Image` → `~/.android/repositories.cfg` | 2단계: 에뮬레이터 설치 |
| 8 | `platform-tools`, `emulator`, `platforms;android-34`, `build-tools`, **Pleos 이미지** 설치 | 2단계 |
| 9 | AVD `Pleos_Connect_v2.1.0` 생성 (RAM 4GB, Cold boot, GPU host) | 2단계: AVD 생성 |
| 10 | Pleos 계정 안내 + 샘플 앱 빌드로 Vehicle SDK 의존성 검증 | 0·3~6단계 |

- Apple Silicon: `system-images;android-34;pleos_car_emulator;arm64-v8a` (`crp-arm64-sys-img.xml`)
- Intel Mac: `system-images;android-34;pleos_car_emulator;x86_64` (`crp-sys-img.xml`)
- Pleos 이미지는 약 **4.7GB** 입니다. 설치 중 42dot *Pleos Connect SDK License Agreement* 동의를 직접 입력해야 합니다.
- 7단계는 Android Studio 의 *SDK Manager > SDK Update Sites* 에 추가하는 것과 같아서, Studio 에서도 바로 보입니다.

버전 값은 모두 [`config/versions.env`](config/versions.env) 에 모여 있습니다.

## 웹에서 직접 해야 하는 것 (자동화 불가)

1. [Pleos Playground](https://developers.pleos.ai) 회원가입 / 로그인
2. **Workspace > My Project > 프로젝트 생성**
3. 사이드바 **SDK** 메뉴에서 필요한 SDK 사용 신청
   - Vehicle State, NaviHelper: 신청 없이 사용 가능
   - 제휴 계약 필요 SDK: partnership@pleos.ai 문의

## 샘플 앱 (`sample/`)

문서의 첫 API 호출 예제(운전석 문 위치 조회)를 그대로 옮긴 Android Automotive 앱입니다.

- Kotlin, `minSdk 28` / `compileSdk 34`
- Maven: `https://nexus-playground.pleos.ai/repository/maven-releases/`
- 의존성: `ai.pleos.playground:Vehicle:2.3.2`
- 권한: `pleos.car.permission.CAR_DOORS`
- AGP 9.5.1 (Kotlin 내장) / Gradle 9.9.0 (wrapper 포함) — Android Studio 2026.2 내장 JDK 25 와 JDK 17 모두에서 빌드됨

```bash
./scripts/emulator.sh --install
# 또는 Android Studio > Open > sample
```

새 프로젝트를 만들 때는 `sample/settings.gradle.kts` 의 저장소 설정과 `sample/app/build.gradle.kts` 의 의존성을 복사해 쓰면 됩니다.

## 문제 해결

- `./scripts/doctor.sh` 로 어떤 항목이 빠졌는지 먼저 확인하세요.
- Android Studio 첫 실행 마법사에서 SDK 경로를 `~/Library/Android/sdk` (setup 에서 고른 경로) 로 지정하세요.
- Studio 에 실행 버튼(app 구성)이 안 보이면 Gradle sync 가 실패한 것입니다. *File > Sync Project with Gradle Files* 후 Build 창의 오류를 확인하세요. Gradle JDK 는 *Settings > Build Tools > Gradle > Gradle JDK* 에서 바꿀 수 있습니다 (17 이상).
- 예전 Pleos 이미지가 있으면 setup 이 자동으로 삭제 후 재설치합니다.
- 에뮬레이터 로그: `.setup-logs/emulator.log`
- 에뮬레이터 문제: [Emulator troubleshooting](https://developer.android.com/studio/run/emulator-troubleshooting?hl=ko), [Known issues](https://developer.android.com/studio/known-issues?hl=ko)
