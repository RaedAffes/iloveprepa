"use client";

import { useEffect, useRef, useState } from "react";
import { LibraryFolder } from "@/lib/library-folder";
import NotionFolderIcon from "@/components/icons";

function useContainerWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) setWidth(entry.contentRect.width);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return { ref, width };
}

export default function OverviewView({
  folders,
  onOpenFolder,
}: {
  folders: LibraryFolder[];
  onOpenFolder: (path: string[]) => void;
}) {
  const sorted = [...folders].sort((a, b) =>
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
  );
  const { ref, width } = useContainerWidth<HTMLDivElement>();

  const columns = width >= 860 ? 5 : width >= 640 ? 4 : width >= 420 ? 3 : 2;

  if (sorted.length === 0) {
    return (
      <div style={{ padding: "40px 0", display: "flex", justifyContent: "center" }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: "#6B7280" }}>
          Aucune matière disponible
        </span>
      </div>
    );
  }

  return (
    <div ref={ref} style={{ width: "100%" }}>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
          columnGap: 16,
          rowGap: 24,
        }}
      >
        {sorted.map((folder) => (
          <FolderTile
            key={folder.name}
            folder={folder}
            onOpen={() => onOpenFolder([folder.name])}
          />
        ))}
      </div>
    </div>
  );
}

function FolderTile({
  folder,
  onOpen,
}: {
  folder: LibraryFolder;
  onOpen: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="ip-ink"
      data-ink-hover="#EFEFEE"
      style={{
        appearance: "none",
        border: 0,
        cursor: "pointer",
        background: "transparent",
        width: "100%",
        aspectRatio: "0.92",
        borderRadius: 18,
        padding: "12px 8px",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <span
        style={{
          width: 84,
          height: 84,
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          transition: "transform 0.15s ease",
        }}
        onMouseEnter={(e) => (e.currentTarget.style.transform = "scale(1.06)")}
        onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1.0)")}
      >
        <NotionFolderIcon size={56} name={folder.name} />
      </span>
      <span style={{ height: 8 }} />
      <span
        style={{
          fontSize: 13,
          fontWeight: 600,
          lineHeight: 1.25,
          color: "#1B1B1B",
          textAlign: "center",
          display: "-webkit-box",
          WebkitLineClamp: 2,
          WebkitBoxOrient: "vertical",
          overflow: "hidden",
          maxWidth: "100%",
        }}
      >
        {folder.name}
      </span>
    </button>
  );
}