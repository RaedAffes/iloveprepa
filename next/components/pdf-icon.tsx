"use client";

interface Props {
  size?: number;
  color?: string;
}

export default function NotionPdfIcon({
  size = 32,
  color = "#787774",
}: Props) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden
    >
      <path
        d="M5 2.6 H13.8 L19 7.8 V21.4 H5 Z"
        stroke={color}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M13.8 2.6 V7.8 H19"
        stroke={color}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <text
        x="12"
        y="14.8"
        textAnchor="middle"
        style={{
          fontFamily: "var(--font-inter), sans-serif",
          fontSize: "6.4px",
          fontWeight: 700,
          letterSpacing: "0.2px",
          fill: color,
        }}
      >
        PDF
      </text>
    </svg>
  );
}