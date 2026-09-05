@echo off
setlocal
echo [1/2] Building Flutter web app...
pushd webapp
call flutter build web --release --dart-define=API_BASE_URL=https://iloveprepa-r2.ilovepreparatoire.workers.dev
if errorlevel 1 goto :error

echo [2/2] Deploying to Cloudflare Pages...
call npx wrangler pages deploy build/web --project-name=iloveprepa --branch=main
if errorlevel 1 goto :error
popd

echo.
echo Done! The app is live at https://iloveprepa.pages.dev
goto :eof

:error
echo.
echo Something failed. See the messages above.
exit /b 1
