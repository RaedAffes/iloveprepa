import 'dart:js_interop' as js;
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/theme/app_colors.dart';
import 'landing/landing_colors.dart' as landing;

/// Pinned pdf.js release used to render documents inside the app.
const String _pdfJsBase = 'https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38';

/// Renders the PDF at [url] in-app with pdf.js, like a native file viewer:
/// page navigation, zoom controls, fullscreen and download. A Flutter spinner
/// covers the view until the viewer signals it is ready.
class PdfEmbed extends StatefulWidget {
  const PdfEmbed({super.key, required this.url, this.downloadUrl});

  final String url;

  /// Force-download URL (Content-Disposition: attachment) for the toolbar's
  /// download button. Falls back to [url] when omitted.
  final String? downloadUrl;

  @override
  State<PdfEmbed> createState() => _PdfEmbedState();
}

class _PdfEmbedState extends State<PdfEmbed> {
  static int _counter = 0;

  late final String _viewType;
  late final String _readySignal;
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-embed-$_counter';
    _readySignal = '__pdfEmbedReady$_counter';
    _counter++;

    js.globalContext[_readySignal] = (() => _loading.value = false).toJS;

    final url = widget.url;
    final downloadUrl = widget.downloadUrl ?? url;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final container = web.HTMLDivElement()
        ..style.position = 'absolute'
        ..style.inset = '0'
        ..style.width = '100%'
        ..style.height = '100%';

      container.innerHTML = _viewerHtml.toJS;

      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..textContent = _viewerScript(
          url: url,
          downloadUrl: downloadUrl,
          pdfJsBase: _pdfJsBase,
          readySignal: _readySignal,
        );
      container.append(script);

      return container;
    });
  }

  @override
  void dispose() {
    js.globalContext.delete(_readySignal.toJS);
    _loading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        ValueListenableBuilder<bool>(
          valueListenable: _loading,
          builder: (context, loading, _) {
            if (!loading) return const SizedBox.shrink();
            return ColoredBox(
              color: AppColors.surfaceSecondary,
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: landing.AppColors.orange,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

const String _viewerHtml = '''
<div id="root" style="position:absolute;inset:0;display:flex;flex-direction:column;background:#525659;font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;color:#fff;overflow:hidden;">
  <div id="t" style="display:flex;align-items:center;gap:2px;padding:6px 10px;background:#323639;border-bottom:1px solid rgba(0,0,0,.25);flex:0 0 auto;user-select:none;">
    <button id="v" title="Page précédente" disabled>‹</button>
    <span id="i" style="min-width:56px;text-align:center;font-size:13px;font-variant-numeric:tabular-nums;">–</span>
    <button id="x" title="Page suivante" disabled>›</button>
    <span style="flex:1"></span>
    <button id="z-" title="Zoom arrière">−</button>
    <button id="zr" title="Réinitialiser le zoom" style="min-width:46px;text-align:center;font-size:12px;font-variant-numeric:tabular-nums;padding:6px 4px;">100%</button>
    <button id="z+" title="Zoom avant">+</button>
    <span style="width:10px"></span>
    <button id="f" title="Plein écran">⛶</button>
    <button id="d" title="Télécharger">⇩</button>
  </div>
  <div id="bar" style="height:3px;background:linear-gradient(90deg,#ff6b35,#ff9a5c);transition:width .15s;width:0%;flex:0 0 auto;"></div>
  <div id="s" style="flex:1;overflow:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;touch-action:pan-x pan-y;">
    <div id="p" style="display:flex;flex-direction:column;align-items:flex-start;gap:12px;padding:16px 16px 32px;width:max-content;margin:0 auto;touch-action:pan-x pan-y;will-change:transform;"></div>
  </div>
  <style>
    #t button { background:transparent;border:0;color:#e8e8e8;font-size:16px;line-height:1;padding:6px 10px;border-radius:6px;cursor:pointer;font-family:inherit; }
    #t button:hover { background:rgba(255,255,255,.12); }
    #t button:active { background:rgba(255,255,255,.2); }
    #t button:disabled { opacity:.35; cursor:default; }
  </style>
</div>
''';

String _viewerScript({
  required String url,
  required String downloadUrl,
  required String pdfJsBase,
  required String readySignal,
}) {
  return '''
(async () => {
const PDFJS_URL = '$pdfJsBase';
const FILE_URL = '$url';
const DL_URL = '$downloadUrl';
const READY = '$readySignal';

function signalReady() {
  try { window[READY] && window[READY](); } catch (_) {}
}

signalReady();

const scroller = document.getElementById('s');
const pagesDiv = document.getElementById('p');
const progressBar = document.getElementById('bar');
const pageInfo = document.getElementById('i');
const prevBtn = document.getElementById('v');
const nextBtn = document.getElementById('x');
const zoomIn = document.getElementById('z+');
const zoomOut = document.getElementById('z-');
const zoomReset = document.getElementById('zr');
const fullBtn = document.getElementById('f');
const dlBtn = document.getElementById('d');

let pdfjs;
try {
  pdfjs = await import(PDFJS_URL + '/build/pdf.min.mjs');
  pdfjs.GlobalWorkerOptions.workerSrc = PDFJS_URL + '/build/pdf.worker.min.mjs';
} catch (_) {
  return;
}

let pdf = null;
let scale = 1;
let baseScale = 1;
let currentPage = 1;
const canvases = [];
const viewports = [];
const rendered = new Set();
const DPR = Math.min(Math.max(window.devicePixelRatio || 1, 1), 2);
let touching = false;
let pinch = null;
let animRaf = null;

function clampScale(s) { return Math.max(0.2, Math.min(4, s)); }

function pageOffset() {
  const sr = scroller.getBoundingClientRect();
  const pr = pagesDiv.getBoundingClientRect();
  return { x: pr.left - sr.left + scroller.scrollLeft, y: pr.top - sr.top + scroller.scrollTop };
}

function setPageSizes() {
  if (!pdf || viewports.length === 0) return;
  for (let i = 0; i < viewports.length; i++) {
    canvases[i].style.width = Math.floor(viewports[i].width * scale) + 'px';
    canvases[i].style.height = Math.floor(viewports[i].height * scale) + 'px';
  }
}

function updatePage() {
  if (!pdf) return;
  const st = scroller.scrollTop + 20;
  let cur = 1;
  for (let i = 0; i < canvases.length; i++) {
    if (canvases[i].offsetTop - scroller.offsetTop <= st) cur = i + 1;
  }
  currentPage = cur;
  pageInfo.textContent = cur + ' / ' + pdf.numPages;
  prevBtn.disabled = cur <= 1;
  nextBtn.disabled = cur >= pdf.numPages;
}

function goTo(n) {
  if (!pdf || n < 1 || n > pdf.numPages) return;
  scroller.scrollTo({ top: canvases[n - 1].offsetTop - scroller.offsetTop - 12, behavior: 'smooth' });
}

async function renderPage(idx, rs) {
  if (!pdf || rendered.has(idx)) return;
  try {
    const page = await pdf.getPage(idx + 1);
    const vp = page.getViewport({ scale: rs });
    const t = document.createElement('canvas');
    t.width = Math.floor(vp.width);
    t.height = Math.floor(vp.height);
    const ctx = t.getContext('2d');
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    await page.render({ canvasContext: ctx, viewport: vp }).promise;
    if (touching) return;
    const c = canvases[idx];
    c.width = t.width;
    c.height = t.height;
    const cctx = c.getContext('2d');
    cctx.imageSmoothingEnabled = true;
    cctx.imageSmoothingQuality = 'high';
    cctx.drawImage(t, 0, 0);
    rendered.add(idx);
  } catch (_) {}
}

async function renderRemaining() {
  if (!pdf) return;
  const rs = clampScale(scale * DPR);
  for (let i = 1; i < pdf.numPages; i++) {
    if (rendered.has(i)) continue;
    if (touching) { await new Promise(r => setTimeout(r, 100)); i--; continue; }
    await renderPage(i, rs);
    await new Promise(r => setTimeout(r, 0));
  }
}

function animateTo(targetScale, anchorX, anchorY) {
  const ns = clampScale(targetScale);
  if (Math.abs(ns - scale) < 0.005) return;
  const off = pageOffset();
  const ux = (scroller.scrollLeft + anchorX - off.x) / scale;
  const uy = (scroller.scrollTop + anchorY - off.y) / scale;
  const targetSL = off.x + ux * ns - anchorX;
  const targetST = off.y + uy * ns - anchorY;
  const startScale = scale;
  const startSL = scroller.scrollLeft;
  const startST = scroller.scrollTop;
  const startTime = performance.now();
  if (animRaf) cancelAnimationFrame(animRaf);
  function step(now) {
    const t = Math.min(1, (now - startTime) / 180);
    const ease = 1 - Math.pow(1 - t, 3);
    scale = startScale + (ns - startScale) * ease;
    scroller.scrollLeft = startSL + (targetSL - startSL) * ease;
    scroller.scrollTop = startST + (targetST - startST) * ease;
    setPageSizes();
    zoomReset.textContent = Math.round((scale / baseScale) * 100) + '%';
    if (t < 1) { animRaf = requestAnimationFrame(step); }
    else { animRaf = null; setPageSizes(); updatePage(); }
  }
  animRaf = requestAnimationFrame(step);
}

function fitToWidth() {
  if (!pdf || viewports.length === 0) return;
  const s = clampScale((scroller.clientWidth - 32) / viewports[0].width);
  baseScale = s;
  const rect = scroller.getBoundingClientRect();
  animateTo(s, rect.width / 2, rect.height / 2);
}

function touchMid(a, b) {
  const r = scroller.getBoundingClientRect();
  return { x: (a.clientX + b.clientX) / 2 - r.left, y: (a.clientY + b.clientY) / 2 - r.top };
}
function touchDist(a, b) { return Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY); }

scroller.addEventListener('touchstart', (e) => {
  touching = true;
  if (animRaf) { cancelAnimationFrame(animRaf); animRaf = null; }
  if (e.touches.length === 2) {
    e.preventDefault();
    pinch = {
      d0: touchDist(e.touches[0], e.touches[1]),
      disp: scale, start: scale,
      midX: (e.touches[0].clientX + e.touches[1].clientX) / 2,
      midY: (e.touches[0].clientY + e.touches[1].clientY) / 2,
      moved: false,
    };
  }
}, { passive: false });

scroller.addEventListener('touchmove', (e) => {
  if (e.touches.length === 2) {
    e.preventDefault();
    if (!pinch) {
      pinch = {
        d0: touchDist(e.touches[0], e.touches[1]),
        disp: scale, start: scale,
        midX: (e.touches[0].clientX + e.touches[1].clientX) / 2,
        midY: (e.touches[0].clientY + e.touches[1].clientY) / 2,
        moved: false,
      };
    }
    const mid = touchMid(e.touches[0], e.touches[1]);
    const d = touchDist(e.touches[0], e.touches[1]);
    const disp = clampScale(pinch.start * Math.pow(d / pinch.d0, 0.85));
    const ratio = disp / pinch.disp;
    pinch.disp = disp;
    pinch.midX = mid.x;
    pinch.midY = mid.y;
    if (Math.abs(ratio - 1) > 0.001) pinch.moved = true;
    const k = disp / scale;
    pagesDiv.style.transformOrigin = '0 0';
    pagesDiv.style.transform = k === 1 ? '' : 'scale(' + k + ')';
    const off = pageOffset();
    scroller.scrollLeft = (scroller.scrollLeft + mid.x - off.x) * ratio + off.x - mid.x;
    scroller.scrollTop = (scroller.scrollTop + mid.y - off.y) * ratio + off.y - mid.y;
    zoomReset.textContent = Math.round((disp / baseScale) * 100) + '%';
  }
}, { passive: false });

function endPinch() {
  touching = false;
  if (!pinch) return;
  const { disp } = pinch;
  pinch = null;
  const off = pageOffset();
  const lx = scroller.scrollLeft;
  const ty = scroller.scrollTop;
  scale = disp;
  setPageSizes();
  pagesDiv.style.transform = '';
  const off2 = pageOffset();
  scroller.scrollLeft = lx + (off2.x - off.x);
  scroller.scrollTop = ty + (off2.y - off.y);
  zoomReset.textContent = Math.round((scale / baseScale) * 100) + '%';
  updatePage();
}
scroller.addEventListener('touchend', endPinch, { passive: true });
scroller.addEventListener('touchcancel', endPinch, { passive: true });

let lastTapX = 0, lastTapY = 0, lastTapTime = 0;
scroller.addEventListener('touchend', (e) => {
  if (e.touches.length > 0 || e.changedTouches.length !== 1) return;
  const now = Date.now();
  const touch = e.changedTouches[0];
  const dx = Math.abs(touch.clientX - lastTapX);
  const dy = Math.abs(touch.clientY - lastTapY);
  if (now - lastTapTime < 250 && dx < 15 && dy < 15) {
    const rect = scroller.getBoundingClientRect();
    if (scale > baseScale * 1.3) { fitToWidth(); }
    else { animateTo(1.5 * baseScale, touch.clientX - rect.left, touch.clientY - rect.top); }
    lastTapTime = 0;
  } else {
    lastTapX = touch.clientX;
    lastTapY = touch.clientY;
    lastTapTime = now;
  }
}, { passive: true });

zoomReset.onclick = () => fitToWidth();
prevBtn.onclick = () => goTo(currentPage - 1);
nextBtn.onclick = () => goTo(currentPage + 1);

function zoomBy(d) {
  const r = scroller.getBoundingClientRect();
  animateTo(scale * d, r.width / 2, r.height / 2);
}
zoomIn.onclick = () => zoomBy(1.25);
zoomOut.onclick = () => zoomBy(1 / 1.25);

scroller.addEventListener('wheel', (e) => {
  if (e.ctrlKey || e.metaKey) {
    e.preventDefault();
    if (animRaf) { cancelAnimationFrame(animRaf); animRaf = null; }
    const r = scroller.getBoundingClientRect();
    const x = e.clientX - r.left;
    const y = e.clientY - r.top;
    const ns = clampScale(scale * (e.deltaY > 0 ? 0.92 : 1.08));
    if (Math.abs(ns - scale) < 0.005) return;
    const off = pageOffset();
    const ux = (scroller.scrollLeft + x - off.x) / scale;
    const uy = (scroller.scrollTop + y - off.y) / scale;
    scale = ns;
    setPageSizes();
    pagesDiv.style.transform = '';
    const off2 = pageOffset();
    scroller.scrollLeft = off2.x + ux * scale - x;
    scroller.scrollTop = off2.y + uy * scale - y;
    zoomReset.textContent = Math.round((scale / baseScale) * 100) + '%';
    updatePage();
  }
}, { passive: false });

fullBtn.onclick = () => {
  const root = document.getElementById('root');
  if (document.fullscreenElement) document.exitFullscreen();
  else if (root.requestFullscreen) root.requestFullscreen();
};
dlBtn.onclick = () => {
  const a = document.createElement('a');
  a.href = DL_URL;
  a.download = '';
  document.body.append(a);
  a.click();
  a.remove();
};
scroller.addEventListener('scroll', updatePage, { passive: true });

let lastWidth = 0;
new ResizeObserver(() => {
  if (!pdf) return;
  const w = scroller.clientWidth;
  if (lastWidth === 0) { lastWidth = w; return; }
  const changed = Math.abs(w - lastWidth) > 40;
  lastWidth = w;
  if (changed && (scale < 1.1 * baseScale || Math.abs(w - lastWidth) > 200)) fitToWidth();
}).observe(scroller);

function fetchWithTimeout(url, timeoutMs) {
  return new Promise((resolve, reject) => {
    const controller = new AbortController();
    const timer = setTimeout(() => { controller.abort(); reject(new Error('timeout')); }, timeoutMs);
    fetch(url, { signal: controller.signal }).then(r => { clearTimeout(timer); resolve(r); }, e => { clearTimeout(timer); reject(e); });
  });
}

let resp;
try {
  resp = await fetchWithTimeout(FILE_URL, 30000);
} catch (_) {
  return;
}

if (!resp.ok) {
  return;
}

let buf;
try {
  const totalBytes = Number(resp.headers.get('content-length')) || 0;
  const reader = resp.body.getReader();
  const chunks = [];
  let received = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.length;
    progressBar.style.width = totalBytes > 0
      ? Math.round((received / totalBytes) * 100) + '%'
      : Math.min(90, Math.round((received / (received + 50000)) * 100)) + '%';
  }
  progressBar.style.width = '100%';
  buf = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) { buf.set(chunk, offset); offset += chunk.length; }
} catch (_) {
  return;
}

try {
  pdf = await pdfjs.getDocument({ data: buf }).promise;
} catch (_) {
  return;
}
progressBar.style.width = '0%';

const totalPages = pdf.numPages;
pageInfo.textContent = '1 / ' + totalPages;

try {
  const firstPage = await pdf.getPage(1);
  const vp1 = firstPage.getViewport({ scale: 1 });
  viewports.push(vp1);

  const c1 = document.createElement('canvas');
  c1.style.background = '#fff';
  c1.style.boxShadow = '0 2px 8px rgba(0,0,0,.35)';
  c1.style.touchAction = 'pan-x pan-y';
  pagesDiv.append(c1);
  canvases.push(c1);

  const fitS = clampScale((scroller.clientWidth - 32) / vp1.width);
  baseScale = fitS;
  scale = fitS;
  c1.style.width = Math.floor(vp1.width * scale) + 'px';
  c1.style.height = Math.floor(vp1.height * scale) + 'px';

  const initRs = clampScale(scale * DPR);
  const initVp = firstPage.getViewport({ scale: initRs });
  c1.width = Math.floor(initVp.width);
  c1.height = Math.floor(initVp.height);
  const ctx = c1.getContext('2d');
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  await firstPage.render({ canvasContext: ctx, viewport: initVp }).promise;
  rendered.add(0);

  zoomReset.textContent = '100%';
  scroller.scrollTop = 0;
  updatePage();
} catch (_) {
  return;
}

for (let i = 2; i <= totalPages; i++) {
  try {
    const page = await pdf.getPage(i);
    viewports.push(page.getViewport({ scale: 1 }));
  } catch (_) {
    viewports.push(viewports[0]);
  }
  const canvas = document.createElement('canvas');
  canvas.style.background = '#fff';
  canvas.style.boxShadow = '0 2px 8px rgba(0,0,0,.35)';
  canvas.style.touchAction = 'pan-x pan-y';
  pagesDiv.append(canvas);
  canvases.push(canvas);
}
setPageSizes();
renderRemaining();
})();
''';
}
