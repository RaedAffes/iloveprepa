interface Entry {
  el: HTMLElement;
  onScroll: () => void;
  onMove: (e: PointerEvent) => void;
  onLeave: () => void;
}

const SHOW_MS = 600;
const GUTTER_BAND = 16;

export function setupFlutterScrollbars(): () => void {
  const attached = new WeakSet<HTMLElement>();
  const timers = new WeakMap<HTMLElement, number>();
  const entries: Entry[] = [];

  const scheduleHide = (el: HTMLElement) => {
    const prev = timers.get(el);
    if (prev != null) window.clearTimeout(prev);
    timers.set(
      el,
      window.setTimeout(() => el.classList.remove("ip-scroll-on"), SHOW_MS),
    );
  };
  const show = (el: HTMLElement) => {
    el.classList.add("ip-scroll-on");
    scheduleHide(el);
  };
  const hide = (el: HTMLElement) => {
    const prev = timers.get(el);
    if (prev != null) window.clearTimeout(prev);
    el.classList.remove("ip-scroll-on");
  };
  const overGutter = (el: HTMLElement, e: PointerEvent) => {
    const r = el.getBoundingClientRect();
    return (
      (el.scrollHeight > el.clientHeight && e.clientX >= r.right - GUTTER_BAND) ||
      (el.scrollWidth > el.clientWidth && e.clientY >= r.bottom - GUTTER_BAND)
    );
  };

  const attach = (el: HTMLElement) => {
    if (attached.has(el)) return;
    attached.add(el);
    el.classList.add("ip-scroll");
    const onScroll = () => show(el);
    const onMove = (e: PointerEvent) => {
      if (e.pointerType !== "mouse") return;
      if (overGutter(el, e)) show(el);
    };
    const onLeave = () => hide(el);
    el.addEventListener("scroll", onScroll, { passive: true });
    el.addEventListener("pointermove", onMove, { passive: true });
    el.addEventListener("pointerleave", onLeave);
    entries.push({ el, onScroll, onMove, onLeave });
  };

  document.querySelectorAll<HTMLElement>(".ip-scroll").forEach(attach);

  const mo = new MutationObserver((muts) => {
    for (const m of muts) {
      for (const n of m.addedNodes) {
        if (!(n instanceof HTMLElement)) continue;
        if (n.classList.contains("ip-scroll")) attach(n);
        n.querySelectorAll<HTMLElement>(".ip-scroll").forEach(attach);
      }
    }
  });
  mo.observe(document.body, { childList: true, subtree: true });

  return () => {
    mo.disconnect();
    for (const x of entries) {
      x.el.removeEventListener("scroll", x.onScroll);
      x.el.removeEventListener("pointermove", x.onMove);
      x.el.removeEventListener("pointerleave", x.onLeave);
    }
  };
}