const SELECTOR = ".ip-ink";

export const INK_COLORS = {
  hover: "rgba(0,0,0,0.04)",
  press: "rgba(188,188,188,0.40)",
  splash: "rgba(200,200,200,0.40)",
};

interface Handle {
  el: HTMLElement;
  fx: HTMLElement;
  hover: HTMLElement;
  press: HTMLElement;
  onEnter: () => void;
  onLeave: () => void;
  onDown: (e: PointerEvent) => void;
  onUp: () => void;
}

/**
 * Global Material 3 InkWell-equivalent for elements tagged `.ip-ink`.
 *
 * Mirrors Flutter defaults for a plain InkWell in a light theme:
 *  - hover overlay:  onSurface-independent black @ 4% (theme.hoverColor)
 *  - pressed fill:   #BCBCBC @ 40% (theme.highlightColor)
 *  - splash/ripple:  #C8C8C8 @ 40% (theme.splashColor), InkRipple factory on
 *                    web. Ripple starts at 30% radius at the tap point, grows
 *                    to the well diagonal over 225ms (Curves.ease), fades out
 *                    over 375ms once released.
 *
 * Per-element overrides via data attributes:
 *  - data-ink-hover  color       (default INK_COLORS.hover)
 *  - data-ink-press  color       (default INK_COLORS.press)
 *  - data-ink-splash color       (default INK_COLORS.splash)
 *  - data-ink-r      px          fixed splash target radius (IconButton style)
 */
export function setupFlutterInk(): () => void {
  const attached = new WeakSet<HTMLElement>();
  const handles = new Map<HTMLElement, Handle>();

  const fadeIn = (layer: HTMLElement) => {
    layer.style.transitionDuration = "100ms";
    layer.style.opacity = "1";
  };
  const fadeOut = (layer: HTMLElement) => {
    layer.style.transitionDuration = "200ms";
    layer.style.opacity = "0";
  };

  const rippleTarget = (el: HTMLElement, rect: DOMRect) => {
    const fixed = el.dataset.inkR;
    if (fixed != null && fixed.trim() !== "") return parseFloat(fixed) || 0;
    return Math.hypot(rect.width, rect.height) / 2;
  };

  const attach = (el: HTMLElement) => {
    if (attached.has(el)) return;
    attached.add(el);

    if (getComputedStyle(el).position === "static") el.style.position = "relative";
    el.style.overflow = "hidden";

    const fx = document.createElement("div");
    fx.className = "ip-ink-fx";

    const hover = document.createElement("div");
    hover.className = "ip-ink-layer ip-ink-hover";
    hover.style.background = el.dataset.inkHover ?? INK_COLORS.hover;

    const press = document.createElement("div");
    press.className = "ip-ink-layer ip-ink-press";
    press.style.background = el.dataset.inkPress ?? INK_COLORS.press;

    fx.append(hover, press);
    el.appendChild(fx);

    const onEnter = () => fadeIn(hover);
    const onLeave = () => fadeOut(hover);
    const onUp = () => fadeOut(press);

    const onDown = (e: PointerEvent) => {
      if (e.button !== 0) return;
      if (el.hasAttribute("disabled")) return;
      const rect = el.getBoundingClientRect();
      fadeIn(press);
      const target = rippleTarget(el, rect);
      if (!(target > 0)) return;
      const size = Math.max(target * 2, 8);
      const splash = document.createElement("span");
      splash.className = "ip-ink-ripple";
      splash.style.cssText =
        `left:${e.clientX - rect.left}px;` +
        `top:${e.clientY - rect.top}px;` +
        `width:${size}px;height:${size}px;` +
        `background:${el.dataset.inkSplash ?? INK_COLORS.splash};`;
      splash.addEventListener("animationend", () => splash.remove());
      fx.appendChild(splash);
    };

    el.addEventListener("pointerenter", onEnter);
    el.addEventListener("pointerleave", onLeave);
    el.addEventListener("pointerdown", onDown);
    el.addEventListener("pointerup", onUp);
    el.addEventListener("pointercancel", onUp);

    handles.set(el, { el, fx, hover, press, onEnter, onLeave, onDown, onUp });
  };

  document.querySelectorAll<HTMLElement>(SELECTOR).forEach(attach);

  const mo = new MutationObserver((muts) => {
    for (const m of muts) {
      for (const n of m.addedNodes) {
        if (!(n instanceof HTMLElement)) continue;
        if (n.matches(SELECTOR)) attach(n);
        n.querySelectorAll<HTMLElement>(SELECTOR).forEach(attach);
      }
    }
  });
  mo.observe(document.body, { childList: true, subtree: true });

  return () => {
    mo.disconnect();
    for (const h of handles.values()) {
      h.el.removeEventListener("pointerenter", h.onEnter);
      h.el.removeEventListener("pointerleave", h.onLeave);
      h.el.removeEventListener("pointerdown", h.onDown);
      h.el.removeEventListener("pointerup", h.onUp);
      h.el.removeEventListener("pointercancel", h.onUp);
      h.fx.remove();
    }
    handles.clear();
  };
}