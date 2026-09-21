"use client";

import { useEffect, useRef, useState } from "react";
import { MdChevronRight, MdFolderOpen, MdVisibility, MdDownload } from "react-icons/md";
import { LibraryFolder } from "@/lib/library-folder";
import { DocumentItem, displayNameOf, extensionOf, isPdfOf } from "@/lib/document-item";
import NotionFolderIcon from "@/components/icons";

function useRowWidth() {
  const ref = useRef<HTMLDivElement>(null);
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

export interface FolderContentProps {
  folder: LibraryFolder;
  currentPath: string[];
  expanded: Set<string>;
  busy: string | null;
  onView: (doc: DocumentItem) => void;
  onDownload: (doc: DocumentItem) => void;
  onToggle: (path: string[]) => void;
}

export default function FolderContentView({
  folder,
  currentPath,
  expanded,
  busy,
  onView,
  onDownload,
  onToggle,
}: FolderContentProps) {
  const files = [...folder.files].sort((a, b) =>
    displayNameOf(a).toLowerCase().localeCompare(displayNameOf(b).toLowerCase()),
  );
  const subfolders = [...folder.children.values()].sort((a, b) =>
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
  );

  if (files.length === 0 && subfolders.length === 0) {
    return <EmptyFolder />;
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "stretch" }}>
      {files.length > 0 && (
        <>
          <DocumentsWindow files={files} busy={busy} onView={onView} onDownload={onDownload} />
          {subfolders.length > 0 && <div style={{ height: 16 }} />}
        </>
      )}
      {subfolders.map((child) => (
        <div key={child.name} style={{ paddingBottom: 12 }}>
          <MainFolderSection
            folder={child}
            path={[...currentPath, child.name]}
            expanded={expanded}
            busy={busy}
            onView={onView}
            onDownload={onDownload}
            onToggle={onToggle}
          />
        </div>
      ))}
    </div>
  );
}

function EmptyFolder() {
  return (
    <div
      style={{
        padding: "40px 24px",
        background: "#F7F7F5",
        borderRadius: 18,
        border: "1px solid #E9E9E7",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      <div
        style={{
          width: 52,
          height: 52,
          borderRadius: 16,
          background: "#E8EDFA",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#2F6FED",
        }}
      >
        <MdFolderOpen size={26} />
      </div>
      <div style={{ height: 16 }} />
      <span style={{ fontSize: 13, fontWeight: 600, color: "#1B1B1B" }}>Ce dossier est vide</span>
      <div style={{ height: 4 }} />
      <span style={{ fontSize: 12, fontWeight: 500, color: "#6B7280", textAlign: "center" }}>
        Aucun dossier ou document ici pour le moment.
      </span>
    </div>
  );
}

function MainFolderSection({
  folder,
  path,
  expanded,
  busy,
  onView,
  onDownload,
  onToggle,
}: {
  folder: LibraryFolder;
  path: string[];
  expanded: Set<string>;
  busy: string | null;
  onView: (doc: DocumentItem) => void;
  onDownload: (doc: DocumentItem) => void;
  onToggle: (path: string[]) => void;
}) {
  const pathKey = path.join("/");
  const isExpanded = expanded.has(pathKey);
  const files = [...folder.files].sort((a, b) =>
    displayNameOf(a).toLowerCase().localeCompare(displayNameOf(b).toLowerCase()),
  );
  const subfolders = [...folder.children.values()].sort((a, b) =>
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
  );

  return (
<div
        style={{
          background: "#FFFFFF",
          borderRadius: 18,
          border: "1px solid #E9E9E7",
          boxShadow: "0 2px 8px rgba(23,24,28,0.04)",
          overflow: "hidden",
        }}
      >
        <button
          type="button"
          onClick={() => onToggle(path)}
          className="ip-ink"
        style={{
          appearance: "none",
          border: 0,
          cursor: "pointer",
          width: "100%",
          textAlign: "left",
          display: "flex",
          alignItems: "center",
          padding: "12px 14px",
          borderRadius: 18,
          background: isExpanded ? "#E8EDFA" : "#FFFFFF",
        }}
      >
        <MdChevronRight
          aria-hidden
          style={{
            fontSize: 20,
            color: "#6B7280",
            flexShrink: 0,
            transform: isExpanded ? "rotate(90deg)" : undefined,
            transition: "transform 0.18s ease",
          }}
        />
        <span style={{ width: 6 }} />
        <NotionFolderIcon size={24} />
        <span style={{ width: 8 }} />
        <span
          style={{
            flex: 1,
            minWidth: 0,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            fontWeight: 700,
            fontSize: 14,
            color: "#1B1B1B",
          }}
        >
          {folder.name}
        </span>
      </button>
      {isExpanded && (
        <>
          <div style={{ height: 1, background: "#E9E9E7" }} />
          {files.length > 0 && (
            <DocumentsWindow files={files} busy={busy} onView={onView} onDownload={onDownload} />
          )}
          {subfolders.length > 0 && (
            <div style={{ padding: 12, display: "flex", flexDirection: "column", gap: 10 }}>
              {subfolders.map((child) => (
                <MainFolderSection
                  key={child.name}
                  folder={child}
                  path={[...path, child.name]}
                  expanded={expanded}
                  busy={busy}
                  onView={onView}
                  onDownload={onDownload}
                  onToggle={onToggle}
                />
              ))}
            </div>
          )}
          {files.length === 0 && subfolders.length === 0 && (
            <div style={{ padding: 16 }}>
              <span style={{ fontSize: 13, color: "#6B7280" }}>Dossier vide</span>
            </div>
          )}
        </>
      )}
    </div>
  );
}

function DocumentsWindow({
  files,
  busy,
  onView,
  onDownload,
}: {
  files: DocumentItem[];
  busy: string | null;
  onView: (doc: DocumentItem) => void;
  onDownload: (doc: DocumentItem) => void;
}) {
  return (
    <div
      style={{
        background: "#FFFFFF",
        borderRadius: 18,
        border: "1px solid #E9E9E7",
        boxShadow: "0 2px 8px rgba(23,24,28,0.04)",
        overflow: "hidden",
      }}
    >
      {files.map((doc, i) => (
        <FileRow
          key={doc.name}
          doc={doc}
          isFirst={i === 0}
          isLast={i === files.length - 1}
          busy={busy === doc.name}
          onView={() => onView(doc)}
          onDownload={() => onDownload(doc)}
        />
      ))}
    </div>
  );
}

function FileRow({
  doc,
  isFirst,
  isLast,
  busy,
  onView,
  onDownload,
}: {
  doc: DocumentItem;
  isFirst: boolean;
  isLast: boolean;
  busy: boolean;
  onView: () => void;
  onDownload: () => void;
}) {
  const { ref, width } = useRowWidth();
  const compact = width > 0 && width < 560;
  const typeLabel = isPdfOf(doc)
    ? "PDF"
    : extensionOf(doc).length === 0
      ? "Fichier"
      : extensionOf(doc).toUpperCase();

  return (
    <div
      ref={ref}
      className="file-row ip-ink"
      data-ink-hover="#F2F5FD"
      style={{
        padding: "12px 16px",
        borderBottom: isLast ? undefined : "1px solid #E9E9E7",
        borderRadius: isFirst
          ? "18px 18px 0 0"
          : isLast
            ? "0 0 18px 18px"
            : 0,
        display: "flex",
        alignItems: "center",
        gap: 8,
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontWeight: 700,
            fontSize: 13.5,
            color: "#1B1B1B",
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {displayNameOf(doc)}
        </div>
        <div style={{ height: 2 }} />
        <div style={{ fontSize: 11.5, fontWeight: 500, color: "#6B7280" }}>{typeLabel}</div>
      </div>
      {compact ? (
        <div style={{ display: "inline-flex", alignItems: "center", flexShrink: 0 }}>
          <IconAction onClick={busy ? undefined : onView} tooltip="Voir" color="#1B1B1B">
            <MdVisibility size={18} />
          </IconAction>
          <IconAction onClick={busy ? undefined : onDownload} tooltip="Télécharger" color="#F5A623">
            {busy ? <Spinner size={16} color="#F5A623" /> : <MdDownload size={18} />}
          </IconAction>
        </div>
      ) : (
        <div style={{ display: "inline-flex", alignItems: "center", flexShrink: 0 }}>
          <button
            type="button"
            onClick={busy ? undefined : onView}
            className="ip-ink"
            data-ink-hover="rgba(27,27,27,0.08)"
            data-ink-press="rgba(27,27,27,0.12)"
            data-ink-splash="rgba(27,27,27,0.12)"
            style={{
              appearance: "none",
              cursor: busy ? "default" : "pointer",
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              padding: "0 16px",
              height: 40,
              borderRadius: 12,
              background: "#FFFFFF",
              border: "1.2px solid #1B1B1B",
              color: "#1B1B1B",
              fontSize: 14,
              fontWeight: 400,
            }}
          >
            <MdVisibility size={16} /> Voir
          </button>
          <span style={{ width: 8 }} />
          <button
            type="button"
            onClick={busy ? undefined : onDownload}
            className="ip-ink"
            data-ink-hover="rgba(27,27,27,0.08)"
            data-ink-press="rgba(27,27,27,0.12)"
            data-ink-splash="rgba(27,27,27,0.12)"
            style={{
              appearance: "none",
              cursor: busy ? "default" : "pointer",
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              padding: "0 16px",
              height: 40,
              borderRadius: "999px",
              background: "#F5A623",
              border: "none",
              color: "#1B1B1B",
              fontSize: 12,
              fontWeight: 500,
            }}
          >
            {busy ? <Spinner size={14} color="#1B1B1B" /> : <MdDownload size={16} />}
            {busy ? "…" : "Télécharger"}
          </button>
        </div>
      )}
    </div>
  );
}

function IconAction({
  onClick,
  tooltip,
  color,
  children,
}: {
  onClick?: () => void;
  tooltip: string;
  color: string;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      title={tooltip}
      aria-label={tooltip}
      onClick={onClick}
      disabled={!onClick}
      className="ip-ink"
      data-ink-hover="rgba(27,27,27,0.08)"
      data-ink-press="rgba(27,27,27,0.12)"
      data-ink-splash="rgba(27,27,27,0.12)"
      style={{
        appearance: "none",
        border: 0,
        background: "none",
        cursor: onClick ? "pointer" : "default",
        color,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        width: 48,
        height: 48,
        padding: 0,
        borderRadius: 12,
        opacity: onClick ? 1 : 0.6,
      }}
    >
      {children}
    </button>
  );
}

function Spinner({ size, color }: { size: number; color: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden style={{ animation: "ip-spin 1s linear infinite" }}>
      <circle cx="12" cy="12" r="10" fill="none" stroke={color} strokeWidth="3" strokeOpacity="0.25" />
      <path d="M12 2a10 10 0 0 1 10 10" fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" />
    </svg>
  );
}

export { Spinner };