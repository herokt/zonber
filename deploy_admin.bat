@echo off
REM 백오피스 배포 — 웹 번들 + Firestore 규칙·색인까지 함께 올린다.
REM  규칙(firestore.rules)·색인(firestore.indexes.json)을 안 올리면 플레이 기록(users/{uid}/runs) 저장·조회가 막힌다.
echo [1/3] Building backoffice...
set MSYS_NO_PATHCONV=1
call flutter build web --target=lib/backoffice/main_backoffice.dart --output=hosting_root/secret_admin --base-href=/secret_admin/
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo [2/3] Deploying Firestore rules and indexes...
call firebase deploy --only firestore:rules,firestore:indexes
if errorlevel 1 (
    echo Firestore deploy failed!
    pause
    exit /b 1
)

echo [3/3] Deploying hosting (with share page /get/)...
REM 공유용 페이지(OS별 스토어 이동 + 미리보기) — hosting_root 는 git 에 없어서 매번 만든다
call node scripts/make_share_page.mjs
if errorlevel 1 (
    echo Share page build failed!
    pause
    exit /b 1
)
call firebase deploy --only hosting
if errorlevel 1 (
    echo Deploy failed!
    pause
    exit /b 1
)

echo Done!
pause
