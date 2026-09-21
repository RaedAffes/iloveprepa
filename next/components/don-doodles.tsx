"use client";

import { Fragment, useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";

function useSize<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const r = entry.contentRect;
        setSize({ w: r.width, h: r.height });
      }
    });
    obs.observe(el);
    return () => obs.disconnect();
  }, []);
  return { ref, size };
}

const ORANGE = "#FF923C";

interface Stroke {
  stroke: string;
  strokeOpacity: number;
  strokeWidth: number;
  fill: "none";
  strokeLinecap: "round";
  strokeLinejoin: "round";
}

function pen(alpha: number, s: number): Stroke {
  return {
    stroke: ORANGE,
    strokeOpacity: alpha,
    strokeWidth: 2.2 * s,
    fill: "none",
    strokeLinecap: "round",
    strokeLinejoin: "round",
  };
}

function dotPath(cx: number, cy: number, r: number, alpha: number): ReactNode {
  return <circle cx={cx} cy={cy} r={r} fill={ORANGE} stroke="none" fillOpacity={alpha} />;
}

function sparklePath(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  let d = "";
  for (let i = 0; i < 8; i++) {
    const angle = -Math.PI / 2 + (i * Math.PI) / 4;
    const radius = i % 2 === 0 ? r * 0.34 : r;
    const x = cx + Math.cos(angle) * radius;
    const y = cy + Math.sin(angle) * radius;
    d += i === 0 ? `M${x.toFixed(2)},${y.toFixed(2)} ` : `L${x.toFixed(2)},${y.toFixed(2)} `;
  }
  d += "Z";
  return <path d={d} {...p} />;
}

function handStar(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  let d = "";
  for (let i = 0; i < 10; i++) {
    const angle = -Math.PI / 2 + (i * Math.PI) / 5;
    const radius = i % 2 === 0 ? r : r * 0.46;
    const x = cx + Math.cos(angle) * radius;
    const y = cy + Math.sin(angle) * radius;
    d += i === 0 ? `M${x.toFixed(2)},${y.toFixed(2)} ` : `L${x.toFixed(2)},${y.toFixed(2)} `;
  }
  d += "Z";
  return <path d={d} {...p} />;
}

function heartPath(cx: number, cy: number, s: number, p: Stroke): ReactNode {
  return (
    <path
      d={`M${cx.toFixed(2)},${(cy + s).toFixed(2)} C${(cx - 1.15 * s).toFixed(2)},${(cy + 0.1 * s).toFixed(2)} ${(cx - 1.05 * s).toFixed(2)},${(cy - 0.6 * s).toFixed(2)} ${cx.toFixed(2)},${(cy - 0.18 * s).toFixed(2)} C${(cx + 1.05 * s).toFixed(2)},${(cy - 0.6 * s).toFixed(2)} ${(cx + 1.15 * s).toFixed(2)},${(cy + 0.1 * s).toFixed(2)} ${cx.toFixed(2)},${(cy + s).toFixed(2)}`}
      {...p}
    />
  );
}

function smiley(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  const cc = r * 0.11;
  return (
    <g {...p}>
      <circle cx={cx} cy={cy} r={r} />
      <circle cx={cx - r * 0.35} cy={cy - r * 0.12} r={cc} />
      <circle cx={cx + r * 0.35} cy={cy - r * 0.12} r={cc} />
      <path
        d={`M${(cx - r * 0.6).toFixed(2)},${(cy + r * 0.25).toFixed(2)} A${(r * 0.62).toFixed(2)},${(r * 0.62).toFixed(2)} 0 0 1 ${(cx + r * 0.6).toFixed(2)},${(cy + r * 0.25).toFixed(2)}`}
      />
    </g>
  );
}

function sunny(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  const rays: ReactNode[] = [];
  for (let i = 0; i < 8; i++) {
    const a = (i * Math.PI) / 4;
    const x1 = cx + Math.cos(a) * (r + 4);
    const y1 = cy + Math.sin(a) * (r + 4);
    const x2 = cx + Math.cos(a) * (r + 11);
    const y2 = cy + Math.sin(a) * (r + 11);
    rays.push(<path key={i} d={`M${x1.toFixed(2)},${y1.toFixed(2)} L${x2.toFixed(2)},${y2.toFixed(2)}`} {...p} />);
  }
  return (
    <g>
      <circle cx={cx} cy={cy} r={r} {...p} />
      {rays}
    </g>
  );
}

function flower(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  const petals: ReactNode[] = [];
  for (let k = 0; k < 5; k++) {
    const a = (k * 2 * Math.PI) / 5;
    petals.push(
      <circle key={k} cx={cx + Math.cos(a) * r} cy={cy + Math.sin(a) * r} r={r * 0.48} {...p} />,
    );
  }
  return (
    <g>
      {petals}
      <circle cx={cx} cy={cy} r={r * 0.3} {...p} />
    </g>
  );
}

function balloon(cx: number, cy: number, r: number, p: Stroke): ReactNode {
  return (
    <g {...p}>
      <path
        d={`M${(cx - r).toFixed(2)},${(cy - r * 0.55).toFixed(2)} C${(cx - r).toFixed(2)},${(cy - r * 1.15).toFixed(2)} ${(cx + r).toFixed(2)},${(cy - r * 1.15).toFixed(2)} ${(cx + r).toFixed(2)},${(cy - r * 0.55).toFixed(2)} C${(cx + r).toFixed(2)},${(cy + r * 0.75).toFixed(2)} ${cx.toFixed(2)},${(cy + r * 1.05).toFixed(2)} ${cx.toFixed(2)},${(cy + r * 1.05).toFixed(2)} C${cx.toFixed(2)},${(cy + r * 1.05).toFixed(2)} ${(cx - r).toFixed(2)},${(cy + r * 0.75).toFixed(2)} ${(cx - r).toFixed(2)},${(cy - r * 0.55).toFixed(2)}`}
      />
      <path d={`M${cx.toFixed(2)},${(cy + r * 1.05).toFixed(2)} C${(cx - r * 0.5).toFixed(2)},${(cy + r * 1.6).toFixed(2)} ${(cx + r * 0.5).toFixed(2)},${(cy + r * 1.9).toFixed(2)} ${cx.toFixed(2)},${(cy + r * 2.4).toFixed(2)}`} />
    </g>
  );
}

function personJoy(cx: number, cy: number, s: number, p: Stroke): ReactNode {
  return (
    <g {...p}>
      <circle cx={cx} cy={cy - 0.55 * s} r={0.18 * s} />
      <path d={`M${cx.toFixed(2)},${(cy - 0.35 * s).toFixed(2)} L${cx.toFixed(2)},${(cy + 0.35 * s).toFixed(2)}`} />
      <path d={`M${cx.toFixed(2)},${(cy - 0.12 * s).toFixed(2)} L${(cx - 0.5 * s).toFixed(2)},${(cy - 0.55 * s).toFixed(2)}`} />
      <path d={`M${cx.toFixed(2)},${(cy - 0.12 * s).toFixed(2)} L${(cx + 0.5 * s).toFixed(2)},${(cy - 0.55 * s).toFixed(2)}`} />
      <path d={`M${cx.toFixed(2)},${(cy + 0.35 * s).toFixed(2)} L${(cx - 0.2 * s).toFixed(2)},${(cy + 0.7 * s).toFixed(2)}`} />
      <path d={`M${cx.toFixed(2)},${(cy + 0.35 * s).toFixed(2)} L${(cx + 0.2 * s).toFixed(2)},${(cy + 0.7 * s).toFixed(2)}`} />
      <path d={`M${(cx - 0.09 * s).toFixed(2)},${(cy - 0.52 * s).toFixed(2)} A${0.09 * s},${0.09 * s} 0 0 1 ${(cx + 0.09 * s).toFixed(2)},${(cy - 0.52 * s).toFixed(2)}`} />
    </g>
  );
}

function scribble(startX: number, startY: number, length: number, amp: number, p: Stroke): ReactNode {
  return (
    <path
      d={`M${startX.toFixed(2)},${startY.toFixed(2)} C${(startX + length * 0.33).toFixed(2)},${(startY - amp).toFixed(2)} ${(startX + length * 0.66).toFixed(2)},${(startY + amp).toFixed(2)} ${(startX + length).toFixed(2)},${startY.toFixed(2)}`}
      {...p}
    />
  );
}

export default function DonDoodles({ width, height }: { width: number; height: number }) {
  const s = Math.min(width, height) / 700;
  const phone = width < 560;
  const g = (alpha: number) => pen(alpha, s);

  const items: ReactNode[] = [];
  if (phone) {
    const ps = s * 1.25;
    const at = (x: number, y: number) => [width * x, height * y] as const;
    items.push(
      smiley(at(0.085, 0.09)[0], at(0.085, 0.09)[1], 15 * ps, g(0.32)),
      sparklePath(at(0.19, 0.105)[0], at(0.19, 0.105)[1], 9 * ps, g(0.26)),
      heartPath(at(0.125, 0.185)[0], at(0.125, 0.185)[1], 10 * ps, g(0.26)),
      sunny(at(0.9, 0.09)[0], at(0.9, 0.09)[1], 14 * ps, g(0.34)),
      handStar(at(0.965, 0.15)[0], at(0.965, 0.15)[1], 10 * ps, g(0.3)),
      flower(at(0.955, 0.27)[0], at(0.955, 0.27)[1], 11 * ps, g(0.3)),
      dotPath(at(0.945, 0.34)[0], at(0.945, 0.34)[1], 1.8 * ps, 0.3),
      balloon(at(0.048, 0.4)[0], at(0.048, 0.4)[1], 11 * ps, g(0.26)),
      personJoy(at(0.075, 0.52)[0], at(0.075, 0.52)[1], 10 * ps, g(0.24)),
      sparklePath(at(0.16, 0.55)[0], at(0.16, 0.55)[1], 8 * ps, g(0.24)),
      heartPath(at(0.1, 0.79)[0], at(0.1, 0.79)[1], 16 * ps, g(0.34)),
      heartPath(at(0.2, 0.87)[0], at(0.2, 0.87)[1], 10 * ps, g(0.26)),
      sparklePath(at(0.055, 0.9)[0], at(0.055, 0.9)[1], 9 * ps, g(0.26)),
      handStar(at(0.93, 0.79)[0], at(0.93, 0.79)[1], 13 * ps, g(0.32)),
      smiley(at(0.84, 0.87)[0], at(0.84, 0.87)[1], 9 * ps, g(0.24)),
      balloon(at(0.955, 0.94)[0], at(0.955, 0.94)[1], 9 * ps, g(0.26)),
      scribble(at(0.3, 0.965)[0], at(0.3, 0.965)[1], width * 0.42, 5 * s, g(0.22)),
    );
  } else {
    items.push(
      smiley(width * 0.11, height * 0.15, 30 * s, g(0.32)),
dotPath(width * 0.06, height * 0.28, 2.0 * s, 0.3),
      dotPath(width * 0.19, height * 0.26, 1.6 * s, 0.26),
      balloon(width * 0.51, height * 0.12, 24 * s, g(0.26)),
      heartPath(width * 0.6, height * 0.26, 13 * s, g(0.24)),
      sunny(width * 0.9, height * 0.16, 24 * s, g(0.34)),
      scribble(width * 0.7, height * 0.28, 56 * s, 7 * s, g(0.24)),
      flower(width * 0.1, height * 0.48, 24 * s, g(0.34)),
      sparklePath(width * 0.16, height * 0.58, 16 * s, g(0.24)),
      flower(width * 0.92, height * 0.52, 20 * s, g(0.32)),
      smiley(width * 0.81, height * 0.61, 15 * s, g(0.24)),
      heartPath(width * 0.14, height * 0.82, 34 * s, g(0.34)),
      dotPath(width * 0.24, height * 0.88, 2.2 * s, 0.3),
      personJoy(width * 0.56, height * 0.88, 22 * s, g(0.24)),
      handStar(width * 0.88, height * 0.82, 26 * s, g(0.32)),
      sparklePath(width * 0.78, height * 0.9, 16 * s, g(0.24)),
    );
}

  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      style={{ position: "absolute", inset: 0, pointerEvents: "none" }}
      aria-hidden
    >
      {items.map((el, i) => (
        <Fragment key={i}>{el}</Fragment>
      ))}
    </svg>
  );
}

export { useSize };

