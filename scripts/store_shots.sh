#!/usr/bin/env bash
# 스토어 스크린샷 원본 캡처 — 연결된 Android 기기에서 스크린샷 모드(lib/store_shot.dart)를 돌리며 화면마다 찍는다.
#
#   flutter build apk --release --dart-define=STORE_SHOT=true
#   adb -s <기기> install -r build/app/outputs/flutter-apk/app-release.apk
#   bash scripts/store_shots.sh <기기 시리얼> [저장 폴더=build/store_shots]
#   node scripts/compose_store_shots.mjs          # 문구·틀을 입혀 store/screenshots_play/ 로
#   (끝나면 보통 빌드를 다시 설치한다 — 스크린샷 모드 앱은 저절로 화면을 넘긴다)
#
# 기기는 잠금을 풀고 화면을 켜 둔다. 앱이 로그에 `STORESHOT <언어>/<이름>` 을 찍으면 그 순간 화면을 캡처한다.
set -euo pipefail
SERIAL="${1:?기기 시리얼을 준다 (adb devices)}"
OUT="${2:-build/store_shots}"
ADB="${ADB:-adb}"
if ! command -v "$ADB" >/dev/null 2>&1 && [ -x "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" ]; then
  ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
fi
PKG=com.zonber.game

mkdir -p "$OUT"
"$ADB" -s "$SERIAL" shell am force-stop "$PKG"
"$ADB" -s "$SERIAL" logcat -c
"$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "앱을 켰다 — 화면마다 캡처한다 (언어 4 × 화면 6)"

# 로그는 파일로 받는다 — 파이프로 읽으면 끝난 뒤에도 logcat 이 다음 줄이 올 때까지 안 끝나서 스크립트가 멈췄다
LOG="$OUT/logcat.txt"
"$ADB" -s "$SERIAL" logcat -v raw -s flutter:I > "$LOG" &
LOGCAT=$!
trap 'kill $LOGCAT 2>/dev/null || true' EXIT

seen=0
while :; do
  sleep 0.3
  mapfile -t lines < <(grep -a "STORESHOT" "$LOG" | tr -d '\r')
  while [ "$seen" -lt "${#lines[@]}" ]; do
    line="${lines[$seen]}"
    seen=$((seen + 1))
    case "$line" in
      *"STORESHOT done"*)
        echo "끝"
        exit 0
        ;;
      *STORESHOT\ *)
        name="${line##*STORESHOT }"
        mkdir -p "$OUT/$(dirname "$name")"
        "$ADB" -s "$SERIAL" exec-out screencap -p > "$OUT/$name.png"
        echo "찍음 $name"
        ;;
    esac
  done
done
