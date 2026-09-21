"use client";

import { useRef, useState } from "react";
import { MdSearch, MdClose } from "react-icons/md";

interface Props {
  value: string;
  onChange: (value: string) => void;
  compact?: boolean;
}

export default function SearchInput({ value, onChange, compact = false }: Props) {
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const fill = compact ? 13 : 15;
  const borderColor = focused
    ? "rgba(55,53,47,0.35)"
    : hovered
      ? "rgba(120,119,116,0.35)"
      : "#E9E9E7";

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        background: "#FFFFFF",
        borderRadius: 14,
        border: `1px solid ${borderColor}`,
        boxShadow: hovered || focused ? "0 2px 8px rgba(23,24,28,0.04)" : undefined,
        padding: compact ? "10px 12px" : "16px 14px",
        transition: "border-color 0.15s ease, box-shadow 0.15s ease",
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <MdSearch aria-hidden style={{ fontSize: compact ? 18 : 21, color: "#787774", flexShrink: 0 }} />
      <input
        ref={inputRef}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        placeholder="Rechercher une matière, un dossier ou un document…"
        style={{
          flex: 1,
          minWidth: 0,
          appearance: "none",
          border: 0,
          outline: "none",
          background: "transparent",
          fontFamily: "var(--font-inter)",
          fontSize: fill,
          color: "#37352F",
        }}
      />
      {value !== "" && (
        <button
          type="button"
          aria-label="Effacer"
          onClick={() => {
            onChange("");
            inputRef.current?.focus();
          }}
          className="ip-ink"
          data-ink-hover="transparent"
          style={{
            appearance: "none",
            border: 0,
            background: "none",
            cursor: "pointer",
            display: "inline-flex",
            padding: 0,
            color: "#787774",
          }}
        >
          <MdClose aria-hidden style={{ fontSize: 18 }} />
        </button>
      )}
      <style>{`input::placeholder { color:#9B9A97; }`}</style>
    </div>
  );
}