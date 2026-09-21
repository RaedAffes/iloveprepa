"use client";

import { useEffect, useRef } from "react";

declare global {
  interface Window {
    __iloveprepaBootHidden?: boolean;
  }
}

export default function BootSplash() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let hidden = false;
    const hideBoot = () => {
      if (hidden) return;
      hidden = true;
      window.__iloveprepaBootHidden = true;
      const el = ref.current;
      if (!el) return;
      el.classList.add("boot-hide");
      window.setTimeout(() => el.remove(), 300);
    };
    window.addEventListener("iloveprepa-first-frame", hideBoot, { once: true });
    window.addEventListener("iloveprepa-data-ready", hideBoot, { once: true });
    if (window.__iloveprepaBootHidden) hideBoot();
    const fallback = window.setTimeout(hideBoot, 10000);
    return () => {
      window.clearTimeout(fallback);
      window.removeEventListener("iloveprepa-first-frame", hideBoot);
      window.removeEventListener("iloveprepa-data-ready", hideBoot);
    };
  }, []);

  return (
    <div
      id="boot-preview"
      aria-hidden="true"
      ref={ref}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 2,
        overflow: "hidden",
        background: "#1B3FA0",
        transition: "opacity 0.25s ease",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <style>{`
        #boot-preview { opacity: 1; pointer-events: auto; }
        #boot-preview.boot-hide { opacity: 0; pointer-events: none; }
      `}</style>
      <div
        style={{
          fontFamily: "var(--font-playfair), Georgia, serif",
          fontSize: 40,
          fontWeight: 700,
          color: "#FFFFFF",
        }}
      >
        I<span style={{ color: "#F44336", fontSize: 36 }}>♥</span>Prepa
      </div>
    </div>
  );
}