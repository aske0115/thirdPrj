#!/bin/zsh
# iOS 실기기 설치: Godot로 Xcode 프로젝트 내보내기 → xcodebuild(자동 서명) → devicectl 설치·실행.
# 사용: ./ios.sh [기기 UDID]  (생략하면 연결된 첫 실기기)
set -e
cd "$(dirname "$0")"
G=/Applications/Godot.app/Contents/MacOS/Godot
DEV=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ && /physical/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}
[ -z "$DEV" ] && { echo "연결된 iPhone이 없습니다(xcrun devicectl list devices)"; exit 1; }
rm -rf build/ios && mkdir -p build/ios && touch build/.gdignore  # Godot가 빌드 결과물을 가져오지 않게
$G --headless --path . --export-debug "iOS" build/ios/BossRush.ipa
cd build/ios
xcodebuild -project BossRush.xcodeproj -scheme BossRush -configuration Debug \
  -destination "id=$DEV" -derivedDataPath dd -allowProvisioningUpdates build | grep -E "error|BUILD"
xcrun devicectl device install app --device "$DEV" dd/Build/Products/Debug-iphoneos/BossRush.app
xcrun devicectl device process launch --device "$DEV" kr.co.daeun.bossrush
