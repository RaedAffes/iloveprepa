@echo off
setlocal
echo [0/4] Refreshing keyword page copies...
pushd webapp
for %%K in (iprepa prepa-tunisie prepa-docs prepa-document prepa-documents documents-prepa prepa-ds prepa-devoir prepa-devoirs devoirs-prepa prepa-examen prepa-examens examens-prepa prepa-exercice prepa-exercices exercices-prepa prepa-cours cours-prepa prepa-td td-prepa prepa-sujet prepa-sujets sujets-prepa prepa-concours concours-prepa prepa-revision prepa-revisions revisions-prepa prepa-corrige prepa-corriges corriges-prepa prepa-mp prepa-pc prepa-pt prepa-t prepa-bg prepa-maths prepa-mathematiques mathematiques-prepa prepa-physique physique-prepa prepa-chimie chimie-prepa prepa-informatique informatique-prepa prepa-svt svt-prepa) do (
  if not exist "web\%%K" mkdir "web\%%K"
  copy /y "web\index.html" "web\%%K\index.html" >nul
)
if errorlevel 1 goto :error

echo [1/4] Building Flutter web app...
call flutter build web --release --wasm --dart-define=API_BASE_URL=https://iloveprepa-r2.ilovepreparatoire.workers.dev
if errorlevel 1 goto :error

echo [2/4] Repairing Material icons (Flutter tree-shaking drops 2 icons used in the app)...
python tools\fix_icons_font.py
if errorlevel 1 goto :error

echo [3/5] Switching engine to same-origin in generated bootstrap...
powershell -NoProfile -Command "(Get-Content -Raw 'build\web\flutter_bootstrap.js') -replace '_flutter\.loader\.load\(\{', '_flutter.loader.load({config:{canvasKitBaseUrl:\"canvaskit\",useLocalCanvasKit:true},' | Set-Content -NoNewline 'build\web\flutter_bootstrap.js'
if errorlevel 1 goto :error

echo [4/5] Deploying to Cloudflare Pages...
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
