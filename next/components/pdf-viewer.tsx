"use client";

import { MdClose } from "react-icons/md";
import { useEffect, useRef, useState } from "react";
import { VIEWER_HTML, viewerScript } from "@/lib/pdf-viewer-templates";

let instanceCounter = 0;

export default function PdfViewer({
  url,
  downloadUrl,
  onClose,
}: {
  url: string;
  downloadUrl: string;
  onClose: () => void;
}) {
  const hostRef = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    const readyName = `__pdfEmbedReady${instanceCounter++}`;

    const win = window as unknown as Record<string, unknown>;
    win[readyName] = () => {
      setLoading(false);
      return undefined;
    };

    host.innerHTML = VIEWER_HTML;
    const script = document.createElement("script");
    script.type = "module";
    script.textContent = viewerScript(url, downloadUrl, readyName);
    host.appendChild(script);

    return () => {
      host.innerHTML = "";
      delete win[readyName];
    };
  }, [url, downloadUrl]);

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 60,
        background: "#FFFFFF",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
        animation: "ip-fade-up 0.18s ease-out",
      }}
    >
      <div
        style={{
          height: 44,
          flexShrink: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "flex-end",
          padding: "0 8px",
          background: "#FFFFFF",
          borderBottom: "1px solid #E9E9E7",
        }}
      >
        <button
          type="button"
          aria-label="Fermer"
          onClick={onClose}
          style={{
            appearance: "none",
            border: 0,
            background: "none",
            cursor: "pointer",
            width: 40,
            height: 40,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            borderRadius: "50%",
            color: "#1B1B1B",
            transition: "background 0.15s ease",
          }}
          onMouseEnter={(e) => (e.currentTarget.style.background = "#F2F2F0")}
          onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
        >
          <MdClose style={{ fontSize: 26 }} />
        </button>
      </div>
      <div style={{ position: "relative", flex: 1, overflow: "hidden" }}>
        <div ref={hostRef} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
        {loading && (
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "#F7F7F5",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <span
              style={{
                width: 44,
                height: 44,
                borderRadius: "50%",
                border: "4px solid rgba(255,146,60,0.2)",
                borderTopColor: "#FF923C",
                animation: "ip-spin 1s linear infinite",
              }}
            />
          </div>
        )}
      </div>
    </div>
  );
}