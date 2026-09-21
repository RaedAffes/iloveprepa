"use client";

import { MdFavorite } from "react-icons/md";
import { useSyncExternalStore } from "react";
import { useEffect, useRef, useState } from "react";
import { statsService } from "@/lib/stats";

export default function AppFooter({ documents }: { documents: number }) {
  const getSnapshot = statsService.getSnapshot.bind(statsService);
  const counters = useSyncExternalStore(
    statsService.subscribe.bind(statsService),
    getSnapshot,
    getSnapshot,
  );
  const boxRef = useRef<HTMLDivElement>(null);
  const wasVisible = useRef(false);
  const [run, setRun] = useState(0);

  useEffect(() => {
    const el = boxRef.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const visible = entry.isIntersecting;
          if (visible && !wasVisible.current) setRun((r) => r + 1);
          wasVisible.current = visible;
        }
      },
      { threshold: 0 },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={boxRef}
      style={{
        width: "100%",
        background: "linear-gradient(to bottom, #000000, #121212)",
        padding: "0 16px",
      }}
    >
      <div style={{ height: 88 }} />
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          justifyContent: "center",
          alignItems: "center",
          gap: 160,
          rowGap: 24,
        }}
      >
        <Metric label="Visites">
          <AnimatedNumber value={counters.visits} run={run} />
        </Metric>
        <Metric label="Documents">
          <AnimatedNumber value={documents} run={run} />
        </Metric>
        <Metric label="Téléchargements">
          <AnimatedNumber value={counters.downloads} run={run} />
        </Metric>
      </div>
      <div style={{ height: 88 }} />
      <div style={{ display: "flex", justifyContent: "center" }}>
        <div style={{ textAlign: "center" }}>
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 6,
              color: "#FFFFFF",
              fontSize: 15,
              fontWeight: 700,
              letterSpacing: 0.2,
            }}
          >
            Made With <MdFavorite aria-hidden style={{ fontSize: 17 }} />
          </div>
          <div style={{ height: 6 }} />
          <div
            style={{
              color: "#FFFFFF",
              fontSize: 15,
              fontWeight: 700,
              letterSpacing: 0.2,
            }}
          >
            by: Raed Affes (Ensi) & Edam Mnif (Supcom)
          </div>
        </div>
      </div>
      <div style={{ height: 24 }} />
    </div>
  );
}

function Metric({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
      {children}
      <div style={{ height: 4 }} />
      <span
        style={{
          fontSize: 12,
          fontWeight: 600,
          letterSpacing: 0.3,
          color: "#B9B7B1",
          fontVariantNumeric: "tabular-nums",
        }}
      >
        {label}
      </span>
    </div>
  );
}

export function AnimatedNumber({ value, run }: { value: number; run: number }) {
  const [display, setDisplay] = useState(0);
  const anim = useRef({ from: 0, to: 0, raf: 0, t0: 0 });
  const prevRun = useRef(run);
  const lastValue = useRef(value);

  useEffect(() => {
    const a = anim.current;
    const dur = 450;
    const animate = (from: number, to: number) => {
      if (a.raf) cancelAnimationFrame(a.raf);
      a.from = from;
      a.to = to;
      a.t0 = performance.now();
      const step = (now: number) => {
        const t = Math.min(1, (now - a.t0) / dur);
        const ease = 1 - Math.pow(1 - t, 3);
        setDisplay(Math.round(a.from + (a.to - a.from) * ease));
        if (t < 1) a.raf = requestAnimationFrame(step);
        else a.raf = 0;
      };
      a.raf = requestAnimationFrame(step);
    };

    if (run !== prevRun.current) {
      prevRun.current = run;
      animate(0, value);
    } else if (value !== lastValue.current) {
      animate(lastValue.current, value);
    }
    lastValue.current = value;

    return () => {
      if (a.raf) cancelAnimationFrame(a.raf);
    };
  }, [value, run]);

  return (
    <span
      style={{
        fontSize: 30,
        fontWeight: 700,
        lineHeight: 1.15,
        letterSpacing: -0.5,
        color: "#FFFFFF",
        fontVariantNumeric: "tabular-nums",
      }}
    >
      {display.toLocaleString("fr-FR")}
    </span>
  );
}