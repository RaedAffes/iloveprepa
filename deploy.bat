@echo off
setlocal
echo [1/4] Building Flutter web app...
pushd webapp
call flutter build web --release --wasm --dart-define=API_BASE_URL=https://iloveprepa-r2.ilovepreparatoire.workers.dev
if errorlevel 1 goto :error

echo [2/4] Repairing Material icons (Flutter tree-shaking drops 2 icons used in the app)...
python tools\fix_icons_font.py
if errorlevel 1 goto :error

echo [3/4] Switching engine to same-origin in generated bootstrap...
powershell -NoProfile -Command "(Get-Content -Raw 'build\web\flutter_bootstrap.js') -replace '_flutter\.loader\.load\(\{', '_flutter.loader.load({config:{canvasKitBaseUrl:\"canvaskit\",useLocalCanvasKit:true},' | Set-Content -NoNewline 'build\web\flutter_bootstrap.js'
if errorlevel 1 goto :error

echo [4/4] Deploying to Cloudflare Pages...
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