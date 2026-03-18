@echo off
echo [1/2] Building backoffice...
set MSYS_NO_PATHCONV=1
call flutter build web --target=lib/backoffice/main_backoffice.dart --output=hosting_root/secret_admin --base-href=/secret_admin/
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo [2/2] Deploying to Firebase...
call firebase deploy --only hosting
if errorlevel 1 (
    echo Deploy failed!
    pause
    exit /b 1
)

echo Done!
pause
