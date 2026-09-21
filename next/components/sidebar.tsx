"use client";

import { MdDescription } from "react-icons/md";
import { LibraryFolder } from "@/lib/library-folder";
import { DocumentItem } from "@/lib/document-item";
import { SearchResult } from "@/lib/library-index";
import IloveprepaBrand from "@/components/brand";
import NotionFolderIcon from "@/components/icons";
import SearchInput from "@/components/search-input";

interface SNode {
  name: string;
  path: string[];
  children: Map<string, SNode>;
  files: SearchResult[];
  match?: SearchResult;
}

function ensureNode(root: SNode, segments: string[]): SNode {
  let node = root;
  for (const segment of segments) {
    let next = node.children.get(segment);
    if (!next) {
      next = { name: segment, path: [...node.path, segment], children: new Map(), files: [] };
      node.children.set(segment, next);
    }
    node = next;
  }
  return node;
}

function buildSearchTree(results: SearchResult[]): SNode[] {
  const root: SNode = { name: "", path: [], children: new Map(), files: [] };
  for (const result of results) {
    const node = result.isFolder
      ? ensureNode(root, [...result.path, result.title])
      : ensureNode(root, result.path);
    if (result.isFolder) node.match = result;
    else node.files.push(result);
  }
  return [...root.children.values()].sort((a, b) =>
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
  );
}

function SearchFolderRow({
  name,
  depth,
  isMatch,
  onTap,
}: {
  name: string;
  depth: number;
  isMatch: boolean;
  onTap: () => void;
}) {
  return (
    <div style={{ paddingLeft: depth * 18 }}>
      <button
        type="button"
        onClick={onTap}
        className="sb-row ip-ink"
        style={{ padding: "7px 10px", borderRadius: 10, border: 0 }}
      >
        <span style={{ width: 20 }} />
        <NotionFolderIcon size={24} />
        <span style={{ width: 8 }} />
        <span
          style={{
            flex: 1,
            minWidth: 0,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            textAlign: "left",
            fontSize: 13,
            fontWeight: isMatch ? 600 : 400,
            color: isMatch ? "#FFFFFF" : "rgba(255,255,255,0.7)",
          }}
        >
          {name}
        </span>
      </button>
    </div>
  );
}

function SearchFileRow({
  title,
  depth,
  onTap,
}: {
  title: string;
  depth: number;
  onTap: () => void;
}) {
  return (
    <div style={{ paddingLeft: depth * 18 }}>
      <button
        type="button"
        onClick={onTap}
        className="sb-row ip-ink"
        style={{ padding: "7px 10px", borderRadius: 10, border: 0 }}
      >
        <span style={{ width: 20 }} />
        <MdDescription aria-hidden style={{ fontSize: 16, color: "rgba(255,255,255,0.7)", flexShrink: 0 }} />
        <span style={{ width: 8 }} />
        <span
          style={{
            flex: 1,
            minWidth: 0,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            textAlign: "left",
            fontSize: 13,
            fontWeight: 600,
            color: "#FFFFFF",
          }}
        >
          {title}
        </span>
      </button>
    </div>
  );
}

function SearchResultsList({
  results,
  onOpenFolder,
  onOpenFile,
}: {
  results: SearchResult[];
  onOpenFolder: (path: string[]) => void;
  onOpenFile: (doc: DocumentItem) => void;
}) {
  const roots = buildSearchTree(results);

  const rows: React.ReactNode[] = [];
  const renderNode = (node: SNode, depth: number) => {
    rows.push(
      <SearchFolderRow
        key={`f-${node.path.join("/")}`}
        name={node.name}
        depth={depth}
        isMatch={!!node.match}
        onTap={() => onOpenFolder(node.path)}
      />,
    );
    for (const child of [...node.children.values()].sort((a, b) =>
      a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
    )) {
      renderNode(child, depth + 1);
    }
    for (const file of node.files) {
      rows.push(
        <SearchFileRow
          key={`d-${file.title}-${depth}`}
          title={file.title}
          depth={depth + 1}
          onTap={() => file.document && onOpenFile(file.document)}
        />,
      );
    }
  };
  for (const node of roots) renderNode(node, 0);

  return (
    <div className="ip-scroll" style={{ overflowY: "auto", padding: "4px 10px 24px", height: "100%" }}>
      <div style={{ padding: "4px 10px 8px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <span style={{ fontSize: 13, fontWeight: 600, color: "#FFFFFF" }}>Résultats</span>
        <span style={{ fontSize: 12, fontWeight: 500, color: "rgba(255,255,255,0.7)" }}>{results.length}</span>
      </div>
      {results.length === 0 ? (
        <div style={{ padding: "16px 10px 24px", fontSize: 12, fontWeight: 500, color: "rgba(255,255,255,0.7)" }}>
          Aucun résultat trouvé.
        </div>
      ) : (
        rows
      )}
    </div>
  );
}

export interface SidebarProps {
  root: LibraryFolder;
  currentPath: string[];
  onOpenFolder: (path: string[]) => void;
  onOpenFile: (doc: DocumentItem) => void;
  query: string;
  onSearchChange: (value: string) => void;
  searchResults: SearchResult[];
  onMenu?: () => void;
  onBrandTap?: () => void;
}

export default function LibrarySidebar({
  root,
  currentPath,
  onOpenFolder,
  onOpenFile,
  query,
  onSearchChange,
  searchResults,
  onMenu,
  onBrandTap,
}: SidebarProps) {
  const searching = query.trim().length > 0;
  const subjects = [...root.children.values()].sort((a, b) =>
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()),
  );

  return (
    <aside
      style={{
        width: 320,
        maxWidth: "100%",
        height: "100%",
        background: "#1B3FA0",
        borderRight: "1px solid rgba(255,255,255,0.2)",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <style>{`
        .sb-row { background: transparent; }
      `}</style>
      <div
        style={{
          height: 68,
          display: "flex",
          alignItems: "center",
          padding: "0 20px",
          flexShrink: 0,
        }}
      >
        {onMenu && (
          <>
            <button
              type="button"
              aria-label="Masquer la barre latérale"
              onClick={onMenu}
              className="ip-ink"
              data-ink-hover="rgba(255,255,255,0.12)"
              data-ink-splash="rgba(255,255,255,0.10)"
              data-ink-r="18"
              style={{
                appearance: "none",
                background: "none",
                border: 0,
                cursor: "pointer",
                width: 32,
                height: 32,
                display: "inline-flex",
                alignItems: "center",
                justifyContent: "center",
                borderRadius: 8,
              }}
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="#FFFFFF" aria-hidden>
                <path d="M3 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z" />
              </svg>
            </button>
            <span style={{ width: 8 }} />
          </>
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <IloveprepaBrand fontSize={26} iconSize={24} color="#FFFFFF" onTap={onBrandTap} />
        </div>
      </div>
      <div style={{ height: 1, background: "rgba(255,255,255,0.2)", flexShrink: 0 }} />
      <div style={{ padding: "12px 12px 8px", flexShrink: 0 }}>
        <SearchInput value={query} onChange={onSearchChange} compact />
      </div>
      <div style={{ flex: 1, minHeight: 0, position: "relative" }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            overflowY: "auto",
            padding: "20px 10px 24px",
            display: searching ? "none" : undefined,
          }}
          className="ip-scroll"
        >
          {subjects.map((subject) => {
            const isSubject = currentPath.length > 0 && currentPath[0] === subject.name;
            const isAncestor = isSubject && currentPath.length > 1;
            return (
              <div key={subject.name} style={{ paddingBottom: 10 }}>
                <button
                  type="button"
                  onClick={() => onOpenFolder([subject.name])}
                  className="sb-row ip-ink"
                  style={{
                    padding: "18px 16px",
                    borderRadius: 10,
                    border: 0,
                    background: isSubject && !isAncestor
                      ? "#F5A623"
                      : isAncestor
                        ? "rgba(255,255,255,0.12)"
                        : "transparent",
                    display: "flex",
                    alignItems: "center",
                  }}
                >
                  <span style={{ width: 2 }} />
                  <span style={{ width: 6 }} />
                  <span style={{ width: 48, height: 48, display: "inline-flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    <NotionFolderIcon size={36} name={subject.name} />
                  </span>
                  <span style={{ width: 12 }} />
                  <span
                    style={{
                      flex: 1,
                      minWidth: 0,
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                      whiteSpace: "nowrap",
                      textAlign: "left",
                      fontSize: 16,
                      fontWeight: isSubject ? 700 : 500,
                      color: isSubject ? "#FFFFFF" : "rgba(255,255,255,0.7)",
                    }}
                  >
                    {subject.name}
                  </span>
                </button>
              </div>
            );
          })}
        </div>
        {searching && (
          <div style={{ position: "absolute", inset: 0 }}>
            <SearchResultsList
              results={searchResults}
              onOpenFolder={onOpenFolder}
              onOpenFile={onOpenFile}
            />
          </div>
        )}
      </div>
    </aside>
  );
}