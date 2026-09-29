#!/usr/bin/env bash
# 스토어 스크린샷 원본 캡처 — 연결된 Android 기기에서 스크린샷 모드(lib/store_shot.dart)를 돌리며 화면마다 찍는다.
#
#   flutter build apk --release --dart-define=STORE_SHOT=true
#   adb -s <기기> install -r build/app/outputs/flutter-apk/app-release.apk
#   bash scripts/store_shots.sh <기기 시리얼> [저장 폴더=build/store_shots] [--ipad]
#   node scripts/compose_ios_shots.mjs            # App Store(iPhone·iPad) 이미지로 store/screenshots/ 로
#   node scripts/compose_store_shots.mjs          # 문구·틀을 입혀 store/screenshots_play/ 로
#   (끝나면 보통 빌드를 다시 설치한다 — 스크린샷 모드 앱은 저절로 화면을 넘긴다)
#
# --ipad : 찍는 동안 기기 화면을 iPad 13"(1032×1376pt) 비율 1548×2064 · 240dpi 로 바꿔 앱이 iPad 처럼 그리게 한다.
#          끝나거나 중간에 멈춰도 원래 화면 크기·밀도로 되돌린다(trap).
# 기기는 잠금을 풀고 화면을 켜 둔다(화면 자동 꺼짐을 넉넉히). 캡처 직전마다 화면이 켜져 있고 잠기지 않았는지 보고, 아니면 멈춘다. 앱이 로그에 `STORESHOT <언어>/<이름>` 을 찍으면 그 순간 화면을 캡처한다.
set -euo pipefail
SERIAL="${1:?기기 시리얼을 준다 (adb devices)}"
OUT="${2:-build/store_shots}"
ADB="${ADB:-adb}"
if ! command -v "$ADB" >/dev/null 2>&1 && [ -x "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" ]; then
  ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
fi
PKG=com.zonber.game
IPAD=0
[ "${3:-}" = "--ipad" ] && IPAD=1

mkdir -p "$OUT"

# 원래 화면 설정(사용자가 바꿔 둔 값이 있으면 그 값)을 기억했다가 되돌린다
ORIG_SIZE=$("$ADB" -s "$SERIAL" shell wm size | tr -d '' | awk -F': ' '/Override/ {print $2}')
ORIG_DENSITY=$("$ADB" -s "$SERIAL" shell wm density | tr -d '' | awk -F': ' '/Override/ {print $2}')
restore_display() {
  [ "$IPAD" = 1 ] || return 0
  if [ -n "$ORIG_SIZE" ]; then "$ADB" -s "$SERIAL" shell wm size "$ORIG_SIZE"; else "$ADB" -s "$SERIAL" shell wm size reset; fi
  if [ -n "$ORIG_DENSITY" ]; then "$ADB" -s "$SERIAL" shell wm density "$ORIG_DENSITY"; else "$ADB" -s "$SERIAL" shell wm density reset; fi
  echo "화면 크기·밀도를 되돌렸다"
}
if [ "$IPAD" = 1 ]; then
  "$ADB" -s "$SERIAL" shell wm size 1548x2064
  "$ADB" -s "$SERIAL" shell wm density 240
  echo "iPad 비율로 바꿨다 (1548×2064 · 240dpi)"
fi
"$ADB" -s "$SERIAL" shell am force-stop "$PKG"
"$ADB" -s "$SERIAL" logcat -c
"$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "앱을 켰다 — 화면마다 캡처한다 (언어 4 × 화면 10)"

# 로그는 파일로 받는다 — 파이프로 읽으면 끝난 뒤에도 logcat 이 다음 줄이 올 때까지 안 끝나서 스크립트가 멈췄다
LOG="$OUT/logcat.txt"
"$ADB" -s "$SERIAL" logcat -v raw -s flutter:I > "$LOG" &
LOGCAT=$!
trap 'kill $LOGCAT 2>/dev/null || true; restore_display' EXIT

# 화면이 꺼졌거나 잠겼으면 찍지 않는다 — 잠금 화면(배경 사진 등 개인 화면)이 스토어 이미지에 들어가면 안 된다
screen_ok() {
  "$ADB" -s "$SERIAL" shell dumpsys power | grep -q "mWakefulness=Awake" || return 1
  ! "$ADB" -s "$SERIAL" shell dumpsys window | grep -q "mDreamingLockscreen=true"
}
if ! screen_ok; then echo "화면이 꺼졌거나 잠겨 있다 — 잠금을 풀고 다시 돌린다"; exit 1; fi

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
        if ! screen_ok; then
          echo "화면이 꺼졌거나 잠겼다 — $name 은 찍지 않고 멈춘다(잠금을 풀고 다시 돌린다)"
          exit 1
        fi
        mkdir -p "$OUT/$(dirname "$name")"
        "$ADB" -s "$SERIAL" exec-out screencap -p > "$OUT/$name.png"
        echo "찍음 $name"
        ;;
    esac
  done
done
