"use client";

import { createElement } from "react";
import {
  MdAllInclusive,
  MdPublic,
  MdCo2,
  MdCode,
  MdTranslate,
  MdBuild,
  MdSummarize,
  MdFolder,
} from "react-icons/md";
import type { IconType } from "react-icons/lib";

export function folderColor(name: string): string {
  const n = name.toLowerCase();
  if (n.includes("math")) return "#D4A017";
  if (n.includes("physique")) return "#6FA8DC";
  if (n.includes("chimie")) return "#52A88E";
  if (n.includes("info")) return "#8496B8";
  if (n.includes("langage") || n.includes("langue") || n.includes("fran"))
    return "#C07C3B";
  if (n.includes("sta")) return "#94979E";
  if (n.includes("resume") || n.includes("résumé")) return "#A64747";
  return "#FFD24D";
}

export function folderGlyph(name: string): IconType {
  const n = name.toLowerCase();
  if (n.includes("math")) return MdAllInclusive;
  if (n.includes("physique")) return MdPublic;
  if (n.includes("chimie")) return MdCo2;
  if (n.includes("info")) return MdCode;
  if (n.includes("langage") || n.includes("langue") || n.includes("fran"))
    return MdTranslate;
  if (n.includes("sta")) return MdBuild;
  if (n.includes("resume") || n.includes("résumé")) return MdSummarize;
  return MdFolder;
}

interface FolderIconProps {
  size?: number;
  name?: string | null;
}

export default function NotionFolderIcon({ size = 24, name }: FolderIconProps) {
  if (!name) {
    return (
      <img
        src="/icons/folder.png"
        width={size}
        height={size}
        alt=""
        style={{ objectFit: "contain", display: "block" }}
      />
    );
  }
  const Glyph = folderGlyph(name);
  const color = folderColor(name);
  const n = name.toLowerCase();
  const extra = n.includes("chimie") ? 1.55 : n.includes("info") ? 1.35 : 1;
  const icon = createElement(Glyph, {
    "aria-hidden": true,
    style: { fontSize: size * extra, color },
  });
  if (n.includes("chimie")) {
    return (
      <span
        style={{
          display: "inline-flex",
          transform: "translateY(-4px)",
        }}
      >
        {icon}
      </span>
    );
  }
  return icon;
}