"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import type { DocumentItem } from "@/lib/document-item";
import { documentItemFromJson, documentItemToJson } from "@/lib/document-item";
import type { LibraryFolder } from "@/lib/library-folder";
import { LibraryIndex } from "@/lib/library-index";
import { fetchDocuments } from "@/lib/api";
import { statsService } from "@/lib/stats";

import IloveprepaBrand from "@/components/brand";
import LibrarySidebar from "@/components/sidebar";
import { LoadingSkeleton } from "@/components/skeleton";
import { ComeBackLaterView, EmptyView } from "@/components/state-views";
import OverviewView from "@/components/overview-view";
import FolderContentView from "@/components/folder-content-view";
import AppFooter from "@/components/footer";
import ContactForm from "@/components/contact-form";
import DonView from "@/components/don-view";
import PdfViewer from "@/components/pdf-viewer";

import { viewUrlFor, downloadUrlFor } from "@/lib/config";
import { isMobileWeb, triggerWebDownload } from "@/lib/web";
import { spacing } from "@/lib/tokens";
import { setupFlutterScrollbars } from "@/lib/scrollbars";
import { setupFlutterInk } from "@/lib/ink";

const CACHE_KEY = "flutter.cached_documents";

interface ViewerState {
  name: string;
  url: string;
  downloadUrl: string;
}

function loadCache(): DocumentItem[] {
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((e) => e && typeof e === "object")
      .map((e) => documentItemFromJson(e as Record<string, unknown>));
  } catch {
    return [];
  }
}

export default function Dashboard({ initialPath }: { initialPath?: string[] | null }) {
  const [files, setFiles] = useState<DocumentItem[]>([]);
  const [apiErr, setApiErr] = useState<string | null>(null);
  const [apiSettled, setApiSettled] = useState(false);
  const [currentPath, setCurrentPath] = useState<string[]>([]);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [query, setQuery] = useState("");
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [showContact, setShowContact] = useState(false);
  const [contactEpoch, setContactEpoch] = useState(0);
  const [donOpen, setDonOpen] = useState(false);
  const [supportVisible, setSupportVisible] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [viewer, setViewer] = useState<ViewerState | null>(null);
  const [wide, setWide] = useState(false);
  const [wideReady, setWideReady] = useState(false);

  const lastFilesRef = useRef<string[]>([]);
  const fetchLoop = useRef(0);
  const ready = useRef(false);
  const uiReady = useRef(false);
  const deepLinkApplied = useRef(false);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const index = useMemo(() => new LibraryIndex(files), [files]);
  const searchResults = useMemo(() => index.search(query), [index, query]);
  const current = currentPath.length > 0 ? index.root.descend(currentPath) : null;

  const overviewActive =
    !showContact && currentPath.length === 0 && files.length > 0 && apiErr === null;
  const contentTop = overviewActive ? spacing.lg : spacing.giant + spacing.xxl;

  const rememberFiles = (path: string[]) => {
    let node = index.root;
    const remembered: string[] = [];
    for (const seg of path) {
      const next = node.child(seg);
      if (!next) break;
      node = next;
      remembered.push(seg);
      if (node.files.length > 0) lastFilesRef.current = [...remembered];
    }
  };

  const load = useCallback(async () => {
    const id = ++fetchLoop.current;
    try {
      const docs = await fetchDocuments();
      if (id !== fetchLoop.current) return;
      setFiles(docs);
      setContactEpoch((e) => e + 1);
      try {
        localStorage.setItem(CACHE_KEY, JSON.stringify(docs.map((d) => documentItemToJson(d))));
      } catch {
        /* ignore */
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : "Une erreur est survenue.";
      setApiErr(message);
    } finally {
      if (id === fetchLoop.current) setApiSettled(true);
    }
  }, []);

  const openFolder = (path: string[]) => {
    setShowContact(false);
    setCurrentPath(path);
    setExpanded(new Set(path.slice(0, -1).map((_, i) => path.slice(0, i + 1).join("/"))));
    setQuery("");
    rememberFiles(path);
    if (wide && sidebarCollapsed) setSidebarCollapsed(false);
    else if (!wide) setDrawerOpen(false);
  };

  const toggleNode = (path: string[]) => {
    const key = path.join("/");
    if (!expanded.has(key)) {
      openFolder(path);
    } else {
      const next = new Set(expanded);
      for (const k of Array.from(next)) {
        if (k === key || k.startsWith(key + "/")) next.delete(k);
      }
      setExpanded(next);
    }
  };

  const goHome = () => {
    setCurrentPath([]);
    setExpanded(new Set());
    setQuery("");
    setShowContact(false);
    if (!wide) setDrawerOpen(false);
  };

  const reload = () => {
    setQuery("");
    setApiErr(null);
    void load();
  };

  const openDoc = (doc: DocumentItem) => {
    statsService.logDownload();
    const url = viewUrlFor(doc.name);
    const downloadUrl = downloadUrlFor(doc.name);
    if (isMobileWeb()) {
      setViewer({ name: doc.name, url, downloadUrl });
    } else {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  };

  const downloadDoc = (doc: DocumentItem) => {
    if (busy) return;
    setBusy(doc.name);
    statsService.logDownload();
    try {
      triggerWebDownload(downloadUrlFor(doc.name));
    } finally {
      setTimeout(() => setBusy(null), 400);
    }
  };

  const showToast = (msg: string) => {
    setToast(msg);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2500);
  };

  useEffect(() => () => {
    if (toastTimer.current) clearTimeout(toastTimer.current);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seed cached documents after hydration so SSR matches client
    setFiles(loadCache());
    void load();
  }, [load]);

  useEffect(() => {
    const mq = window.matchMedia("(min-width: 960px)");
    const update = () => {
      setWide(mq.matches);
      setWideReady(true);
      if (mq.matches) setDrawerOpen(false);
    };
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  useEffect(() => {
    const firstFrame = setTimeout(() => {
      window.dispatchEvent(new Event("iloveprepa-first-frame"));
    }, 80);
    const fallback = setTimeout(() => {
      if (!uiReady.current) {
        uiReady.current = true;
        window.dispatchEvent(new Event("iloveprepa-data-ready"));
      }
    }, 6000);
    return () => {
      clearTimeout(firstFrame);
      clearTimeout(fallback);
    };
  }, []);

  useEffect(() => {
    if (!wideReady) return;
    if (ready.current) return;
    if (files.length === 0 && !apiSettled) return;
    ready.current = true;
    if (!wide) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- auto-open drawer once on first frame (external boot behavior)
      setDrawerOpen(true);
      const t = setTimeout(() => {
        if (!uiReady.current) {
          uiReady.current = true;
          window.dispatchEvent(new Event("iloveprepa-data-ready"));
        }
      }, 280);
      return () => clearTimeout(t);
    }
    if (!uiReady.current) {
      uiReady.current = true;
      window.dispatchEvent(new Event("iloveprepa-data-ready"));
    }
    return undefined;
  }, [wideReady, files.length, apiSettled, wide]);

  useEffect(() => {
    const show = setTimeout(() => setSupportVisible(true), 2000);
    const hide = setTimeout(() => setSupportVisible(false), 7000);
    return () => {
      clearTimeout(show);
      clearTimeout(hide);
    };
  }, []);

  useEffect(() => {
    if (deepLinkApplied.current || !initialPath || initialPath.length === 0) {
      deepLinkApplied.current = true;
      return;
    }
    const resolved = index.root.descend(initialPath);
    if (!resolved) return;
    deepLinkApplied.current = true;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- apply deep link once saved data arrives (external data sync)
    setCurrentPath([initialPath[0]]);
    setExpanded(
      new Set(initialPath.slice(0, -1).map((_, i) => initialPath.slice(0, i + 1).join("/"))),
    );
    rememberFiles(initialPath);
  }, [files, initialPath, index, rememberFiles]);

  useEffect(() => setupFlutterScrollbars(), []);
  useEffect(() => setupFlutterInk(), []);

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        height: "100dvh",
        overflow: "hidden",
        background: "#F4F6FB",
      }}
    >
      <div style={{ display: "flex", flex: 1, minHeight: 0 }}>
        {wide && !sidebarCollapsed && (
          <LibrarySidebar
            root={index.root}
            currentPath={currentPath}
            onOpenFolder={openFolder}
            onOpenFile={openDoc}
            query={query}
            onSearchChange={setQuery}
            searchResults={searchResults}
            onMenu={() => setSidebarCollapsed(true)}
            onBrandTap={goHome}
          />
        )}

        <main
          style={{
            flex: 1,
            minWidth: 0,
            display: "flex",
            flexDirection: "column",
            background: "#F4F6FB",
          }}
        >
          <TopBar
            wide={wide}
            showMenu={!wide || sidebarCollapsed}
            showBrand={!wide}
            onMenu={() => (wide ? setSidebarCollapsed(false) : setDrawerOpen(true))}
            onContact={() => setShowContact((v) => !v)}
            onBrandTap={goHome}
          />

          <div className="ip-scroll" style={{ flex: 1, minWidth: 0, minHeight: 0, overflowY: "auto" }}>
            <div style={{ minHeight: "100%" }}>
              {showContact ? (
                <div style={{ minHeight: "100%", display: "flex" }}>
                  <Content
                    loading={!apiSettled && files.length === 0}
                    apiErr={apiErr}
                    filesCount={files.length}
                    showContact={showContact}
                    contactEpoch={contactEpoch}
                    homeFolders={Array.from(index.root.children.values())}
                    current={current}
                    currentPath={currentPath}
                    expanded={expanded}
                    busy={busy}
                    onView={openDoc}
                    onDownload={downloadDoc}
                    onToggle={toggleNode}
                    onOpenFolder={openFolder}
                    onReload={reload}
                  />
                </div>
              ) : (
                <div
                  style={{
                    minHeight: "100%",
                    padding: `${contentTop}px ${spacing.xl}px ${spacing.huge}px`,
                  }}
                >
                  <div style={{ width: "100%", maxWidth: 860, margin: "0 auto" }}>
                    <Content
                      loading={!apiSettled && files.length === 0}
                      apiErr={apiErr}
                      filesCount={files.length}
                      showContact={showContact}
                      contactEpoch={contactEpoch}
                      homeFolders={Array.from(index.root.children.values())}
                      current={current}
                      currentPath={currentPath}
                      expanded={expanded}
                      busy={busy}
                      onView={openDoc}
                      onDownload={downloadDoc}
                      onToggle={toggleNode}
                      onOpenFolder={openFolder}
                      onReload={reload}
                    />
                  </div>
                </div>
              )}
              {!showContact && <AppFooter documents={files.length} />}
            </div>
          </div>
        </main>
      </div>

      {!wide && (
        <DrawerOverlay open={drawerOpen} onClose={() => setDrawerOpen(false)}>
          <LibrarySidebar
            root={index.root}
            currentPath={currentPath}
            onOpenFolder={openFolder}
            onOpenFile={openDoc}
            query={query}
            onSearchChange={setQuery}
            searchResults={searchResults}
            onMenu={() => setDrawerOpen(false)}
            onBrandTap={goHome}
          />
        </DrawerOverlay>
      )}

      {donOpen && (
        <DonPopover
          onClose={() => setDonOpen(false)}
          onCopy={() => {
            if (navigator.clipboard) {
              navigator.clipboard.writeText("25680686");
            }
            showToast("Numéro copié !");
          }}
        />
      )}

      <button
        type="button"
        aria-label="Faire un don"
        title="Faire un don"
        onClick={() => setDonOpen(true)}
        style={{
          appearance: "none",
          border: 0,
          cursor: "pointer",
          position: "fixed",
          right: 16,
          bottom: 16,
          width: 64,
          height: 64,
          borderRadius: "50%",
          background: "#FF923C",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          padding: 14,
          boxShadow: "0 6px 16px rgba(0,0,0,0.3)",
          zIndex: 40,
          transition: "transform 0.38s cubic-bezier(0.33, 1, 0.68, 1)",
        }}
        onMouseEnter={(e) => (e.currentTarget.style.transform = "scale(1.08)")}
        onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1.0)")}
        onMouseDown={(e) => (e.currentTarget.style.transform = "scale(1.08)")}
        onMouseUp={(e) => (e.currentTarget.style.transform = "scale(1.0)")}
        onTouchStart={(e) => (e.currentTarget.style.transform = "scale(1.08)")}
        onTouchEnd={(e) => (e.currentTarget.style.transform = "scale(1.0)")}
      >
        <img src="/icons/don.png" alt="" width={36} height={36} style={{ width: 36, height: 36 }} />
      </button>

      {supportVisible && !donOpen && (
        <button
          type="button"
          onClick={() => setDonOpen(true)}
          style={{
            appearance: "none",
            border: "1px solid rgba(28,35,64,0.12)",
            cursor: "pointer",
            position: "fixed",
            right: 90,
            top: "calc(100dvh - 85.5px)",
            width: 155,
            height: 75,
            borderRadius: 16,
            background: "#FFFFFF",
            boxShadow: "0 4px 12px rgba(0,0,0,0.12)",
            zIndex: 40,
            animation: "ip-fade 0.4s ease-out",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.background = "rgba(27,63,160,0.06)")}
          onMouseLeave={(e) => (e.currentTarget.style.background = "#FFFFFF")}
        >
          <span style={{ fontSize: 17, fontWeight: 700, color: "#1C2340", letterSpacing: 0.2 }}>
            Support Us
          </span>
        </button>
      )}

      {toast && (
        <div
          style={{
            position: "fixed",
            bottom: 24,
            left: "50%",
            transform: "translateX(-50%)",
            background: "#322F35",
            color: "#FFFFFF",
            fontSize: 14,
            fontWeight: 500,
            padding: "12px 16px",
            borderRadius: 8,
            boxShadow: "0 8px 24px rgba(0,0,0,0.25)",
            zIndex: 80,
            animation: "ip-fade-up 0.2s ease-out",
            maxWidth: "calc(100vw - 32px)",
            whiteSpace: "nowrap",
          }}
        >
          {toast}
        </div>
      )}

      {viewer && (
        <PdfViewer
          url={viewer.url}
          downloadUrl={viewer.downloadUrl}
          onClose={() => setViewer(null)}
        />
      )}
    </div>
  );
}

function Content({
  loading,
  apiErr,
  filesCount,
  showContact,
  contactEpoch,
  homeFolders,
  current,
  currentPath,
  expanded,
  busy,
  onView,
  onDownload,
  onToggle,
  onOpenFolder,
  onReload,
}: {
  loading: boolean;
  apiErr: string | null;
  filesCount: number;
  showContact: boolean;
  contactEpoch: number;
  homeFolders: LibraryFolder[];
  current: LibraryFolder | null | undefined;
  currentPath: string[];
  expanded: Set<string>;
  busy: string | null;
  onView: (doc: DocumentItem) => void;
  onDownload: (doc: DocumentItem) => void;
  onToggle: (path: string[]) => void;
  onOpenFolder: (path: string[]) => void;
  onReload: () => void;
}) {
  if (showContact) {
    return (
      <div style={{ width: "100%" }}>
        <ContactForm key={contactEpoch} />
      </div>
    );
  }

  if (loading) {
    return (
      <div style={{ width: "100%" }}>
        <LoadingSkeleton />
      </div>
    );
  }

  if (apiErr) {
    return (
      <div style={{ width: "100%" }}>
        <ComeBackLaterView onRetry={onReload} />
      </div>
    );
  }

  if (filesCount === 0) {
    return (
      <div style={{ width: "100%" }}>
        <EmptyView onRefresh={onReload} />
      </div>
    );
  }

  if (currentPath.length === 0) {
    return (
      <div style={{ width: "100%" }}>
        <OverviewView folders={homeFolders} onOpenFolder={onOpenFolder} />
      </div>
    );
  }

  if (!current) {
    return (
      <div style={{ width: "100%" }}>
        <EmptyView onRefresh={onReload} />
      </div>
    );
  }

  return (
    <div style={{ width: "100%" }}>
      <FolderContentView
        folder={current}
        currentPath={currentPath}
        expanded={expanded}
        busy={busy}
        onView={onView}
        onDownload={onDownload}
        onToggle={onToggle}
      />
    </div>
  );
}

function TopBar({
  wide,
  showMenu,
  showBrand,
  onMenu,
  onContact,
  onBrandTap,
}: {
  wide: boolean;
  showMenu: boolean;
  showBrand: boolean;
  onMenu: () => void;
  onContact: () => void;
  onBrandTap: () => void;
}) {
  return (
    <header
      style={{
        height: 68,
        flexShrink: 0,
        background: "#1B3FA0",
        borderBottom: "1px solid rgba(255,255,255,0.2)",
        display: "flex",
        alignItems: "center",
        padding: wide ? "0 40px" : "0 20px 0 4px",
      }}
    >
      {showMenu && (
        <button
          type="button"
          aria-label="Ouvrir la barre latérale"
          onClick={onMenu}
          className="ip-ink"
          data-ink-hover="rgba(255,255,255,0.12)"
          data-ink-press="rgba(255,255,255,0.10)"
          data-ink-splash="rgba(255,255,255,0.10)"
          data-ink-r="20"
          style={{
            appearance: "none",
            background: "none",
            border: 0,
            cursor: "pointer",
            width: 36,
            height: 40,
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            borderRadius: 8,
            marginRight: 8,
          }}
        >
          <svg viewBox="0 0 24 24" width="24" height="24" fill="#FFFFFF" aria-hidden>
            <path d="M3 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z" />
          </svg>
        </button>
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        {showBrand && (
          <IloveprepaBrand fontSize={26} iconSize={24} color="#FFFFFF" onTap={onBrandTap} />
        )}
      </div>
      <button
        type="button"
        aria-label="Contact"
        onClick={onContact}
        title="Contact"
        style={{
          appearance: "none",
          border: 0,
          background: "none",
          cursor: "pointer",
          padding: 0,
          margin: 0,
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          transition: "transform 0.38s cubic-bezier(0.33, 1, 0.68, 1)",
        }}
        onMouseEnter={(e) => (e.currentTarget.style.transform = "scale(1.08)")}
        onMouseLeave={(e) => (e.currentTarget.style.transform = "scale(1.0)")}
      >
        <img
          src="/icons/contact.png"
          alt=""
          width={40}
          height={40}
          style={{ width: 40, height: 40, objectFit: "contain" }}
        />
      </button>
    </header>
  );
}

function DrawerOverlay({
  open,
  onClose,
  children,
}: {
  open: boolean;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 50,
        pointerEvents: open ? undefined : "none",
      }}
    >
      <div
        onClick={onClose}
        style={{
          position: "absolute",
          inset: 0,
          background: "rgba(0,0,0,0.38)",
          opacity: open ? 1 : 0,
          transition: "opacity 0.28s ease",
        }}
      />
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          bottom: 0,
          width: 320,
          maxWidth: "100%",
          background: "#1B3FA0",
          transform: open ? "translateX(0)" : "translateX(-100%)",
          transition: "transform 0.28s ease",
          boxShadow: "0 0 40px rgba(0,0,0,0.3)",
        }}
      >
        {children}
      </div>
    </div>
  );
}

function DonPopover({ onClose, onCopy }: { onClose: () => void; onCopy: () => void }) {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 55,
        animation: "ip-don-pop 0.24s cubic-bezier(0.33, 1, 0.68, 1)",
      }}
    >
      <div
        onClick={onClose}
        role="button"
        aria-label="Fermer"
        style={{
          position: "absolute",
          inset: 0,
          background: "rgba(0,0,0,0.38)",
          animation: "ip-fade 0.24s ease-out",
        }}
      />
      <div
        style={{
          position: "absolute",
          right: 16,
          bottom: 96,
          width: "min(450px, calc(100vw - 32px))",
          height: "min(660px, calc(100dvh - 104px))",
          background: "#FFFFFF",
          borderRadius: 16,
          overflow: "hidden",
          boxShadow: "0 24px 60px rgba(0,0,0,0.45)",
        }}
      >
        <DonView onCopy={onCopy} onClose={onClose} />
      </div>
    </div>
  );
}