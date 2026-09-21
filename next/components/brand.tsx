"use client";

import { MdFavorite } from "react-icons/md";
import { palette } from "@/lib/tokens";

interface Props {
  fontSize?: number;
  iconSize?: number;
  color?: string;
  onTap?: () => void;
}

export default function IloveprepaBrand({
  fontSize = 26,
  iconSize = 24,
  color,
  onTap,
}: Props) {
  const content = (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        fontFamily: "var(--font-playfair), Georgia, serif",
        fontSize,
        fontWeight: 700,
        lineHeight: 1.3,
        color: color ?? palette.darkCharcoal,
        whiteSpace: "nowrap",
        cursor: onTap ? "pointer" : undefined,
      }}
    >
      I
      <MdFavorite
        aria-hidden
        style={{
          fontSize: iconSize,
          color: "#E53935",
          margin: "0 3px",
          flexShrink: 0,
        }}
      />
      Prepa
    </span>
  );

  if (!onTap) return content;
  return (
    <button
      type="button"
      onClick={onTap}
      title="IlovePrepa"
      style={{
        appearance: "none",
        background: "none",
        border: 0,
        padding: 0,
        margin: 0,
        cursor: "pointer",
      }}
    >
      {content}
    </button>
  );
}