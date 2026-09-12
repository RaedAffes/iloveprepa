@echo off
setlocal
echo [1/6] Generating folder SEO meta + sitemap (from live R2 listing)...
pushd webapp
python tools\generate_folder_meta.py
if errorlevel 1 goto :error
popd

echo [2/6] Building Flutter web app...
pushd webapp
call flutter build web --release --wasm --dart-define=API_BASE_URL=https://iloveprepa-r2.ilovepreparatoire.workers.dev
if errorlevel 1 goto :error

echo [3/6] Prerendering SEO pages (bakes meta into folder + keyword index.html)...
python tools\prerender_seo.py
if errorlevel 1 goto :error

echo [4/6] Repairing Material icons (Flutter tree-shaking drops 2 icons used in the app)...
python tools\fix_icons_font.py
if errorlevel 1 goto :error

echo [5/6] Switching engine to same-origin in generated bootstrap...
powershell -NoProfile -Command "(Get-Content -Raw 'build\web\flutter_bootstrap.js') -replace '_flutter\.loader\.load\(\{', '_flutter.loader.load({config:{canvasKitBaseUrl:\"canvaskit\",useLocalCanvasKit:true},' | Set-Content -NoNewline 'build\web\flutter_bootstrap.js'
if errorlevel 1 goto :error

echo [6/6] Deploying to Cloudflare Pages...
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