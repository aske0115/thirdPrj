# 개발 환경(맥)

## 설치된 것(2026-11-17 기준)
- Godot 4.7.2: `brew install --cask godot` → `/Applications/Godot.app/Contents/MacOS/Godot` (아래 `G`)
- 내보내기 템플릿 4.7.2: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` (GitHub 릴리스 `Godot_v4.7.2-stable_export_templates.tpz`를 풀어 넣음)
- JDK: Godot가 `/opt/homebrew/opt/openjdk@21`을 자동으로 잡음(편집기 설정 `export/android/java_sdk_path`). `openjdk@17`도 설치돼 있음(temurin 패키지는 관리자 암호가 필요해 Homebrew 수식 판을 씀)
- 안드로이드 SDK: `~/Library/Android/sdk` (Android Studio로 설치, platform 36·build-tools 35/36)
- Xcode 27.1(iOS 내보내기 뒤 서명은 사용자가 Xcode에서 Team 선택)

## 자주 쓰는 명령
```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --import                     # 에셋 가져오기(처음 받았을 때·에셋 바꾼 뒤)
$G --path .                                          # 창으로 실행(마우스 끌기 = 터치)
$G --headless --path . -- --bot --quit-at=125        # 봇이 한 판 플레이, STATS·RESULT 줄 출력
$G --path . -- --bot --shot=/tmp/s.png --shot-at=20 --quit-at=21   # 화면 저장(창이 잠깐 뜸)
$G -e --path .                                       # 편집기
```
- 사용자 인자는 `--` 뒤에: `--bot`(자동 플레이), `--seed=N`(도시 배치), `--shot=경로`·`--shot-at=초`, `--quit-at=초`, `--lang=en`.

## iPhone에 설치
```bash
./ios.sh            # 연결된 첫 실기기에 내보내기→빌드→설치→실행
```
- 팀 ID `5DQVG9VR67`(개인 계정, `export_presets.cfg`), 번들 ID 가칭 `kr.co.daeun.midnightwrecker`, 자동 서명(`-allowProvisioningUpdates`). 처음 설치한 기기는 설정 → 일반 → VPN 및 기기 관리에서 개발자 신뢰.
- 결과물 `build/`는 커밋하지 않음.

## 내보내기
- 안드로이드·iOS 설정은 `export_presets.cfg`(배포 담당).
- 편집기 설정 `~/Library/Application Support/Godot/editor_settings-4.7.tres`에 안드로이드 SDK(`~/Library/Android/sdk`)·JDK·디버그 키(`~/Library/Application Support/Godot/keystores/debug.keystore`, 암호 android)가 자동으로 들어가 있음. 다른 맥에서는 편집기 → 편집기 설정 → 내보내기 → Android에서 같은 값을 넣음.
