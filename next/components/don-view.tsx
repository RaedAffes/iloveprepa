"use client";

import { MdSmartphone, MdContentCopy, MdClose } from "react-icons/md";
import { useState } from "react";
import DonDoodles, { useSize } from "@/components/don-doodles";
import { kD17Number } from "@/lib/config";

const ORANGE_HOVER = "rgba(255,146,60,0.08)";
const CARD_BORDER = "1px solid rgba(33,37,41,0.12)";

export default function DonView({
  onCopy,
  onClose,
}: {
  onCopy: () => void;
  onClose: () => void;
}) {
  const [reveal, setReveal] = useState(false);
  const { ref, size } = useSize<HTMLDivElement>();

  return (
    <div
      ref={ref}
      style={{
        position: "relative",
        overflow: "hidden",
        background: "#FFFFFF",
        width: "100%",
        height: "100%",
      }}
    >
      {size.w > 0 && size.h > 0 && <DonDoodles width={size.w} height={size.h} />}

      <button
        type="button"
        aria-label="Fermer"
        title="Fermer"
        onClick={onClose}
        className="ip-ink"
        data-ink-hover="transparent"
        style={{
          appearance: "none",
          border: 0,
          background: "none",
          cursor: "pointer",
          position: "absolute",
          top: 12,
          right: 12,
          width: 46,
          height: 46,
          padding: 0,
          zIndex: 2,
          borderRadius: 24,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          color: "#838788",
          transition: "background 0.15s ease",
        }}
        onMouseEnter={(e) => (e.currentTarget.style.background = ORANGE_HOVER)}
        onMouseLeave={(e) => (e.currentTarget.style.background = "transparent")}
      >
        <MdClose style={{ fontSize: 26 }} />
      </button>

      <div className="ip-scroll" style={{ position: "absolute", inset: 0, overflowY: "auto" }}>
        <div
          style={{
            minHeight: "100%",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            padding: 24,
            boxSizing: "border-box",
          }}
        >
          <div
            style={{
              width: "100%",
              maxWidth: 460,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
            }}
          >
            <div style={{ width: "100%", textAlign: "center" }}>
              <span
                style={{
                  fontFamily: "var(--font-pacifico)",
                  fontSize: 36,
                  color: "#212529",
                  lineHeight: 1.1,
                }}
              >
                Soutenir iloveprepa
              </span>
            </div>
            <div style={{ height: 12 }} />
            <div style={{ width: "100%", textAlign: "center" }}>
              <span
                style={{
                  fontFamily: "var(--font-quicksand)",
                  fontWeight: 600,
                  fontSize: 16,
                  lineHeight: 1.5,
                  color: "#57565C",
                }}
              >
                Votre soutien fait grandir notre idée. Merci de faire partie de
                l’aventure.{" "}
                <svg
                  width={18}
                  height={18}
                  viewBox="0 0 24 24"
                  style={{ display: "inline-block", verticalAlign: "middle", marginLeft: 2 }}
                  aria-hidden
                >
                  <path
                    d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
                    fill="#E53935"
                  />
                </svg>
              </span>
            </div>

            <div style={{ height: 26 }} />

            <button
              type="button"
              onClick={() => setReveal(true)}
              className="ip-ink"
              style={{
                appearance: "none",
                border: 0,
                cursor: "pointer",
                width: "100%",
                height: 60,
                borderRadius: 48,
                background: "#FF923C",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 10,
                fontFamily: "var(--font-quicksand)",
                fontWeight: 700,
                fontSize: 16,
                color: "#FFFFFF",
                padding: 0,
              }}
            >
              <MdSmartphone style={{ fontSize: 22, flexShrink: 0 }} />
              Faire un don via D17
            </button>

            {reveal && (
              <>
                <div style={{ height: 20 }} />
                <div
                  style={{
                    width: "100%",
                    boxSizing: "border-box",
                    border: CARD_BORDER,
                    borderRadius: 24,
                    padding: 20,
                    background: "#FFFFFF",
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                  }}
                >
                  <span
                    style={{
                      fontFamily: "var(--font-quicksand)",
                      fontWeight: 700,
                      fontSize: 14,
                      color: "#838788",
                    }}
                  >
                    Numéro D17
                  </span>
                  <div style={{ height: 12 }} />
                  <div style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
                    <span
                      style={{
                        fontFamily: "var(--font-quicksand)",
                        fontWeight: 700,
                        fontSize: 32,
                        letterSpacing: 2,
                        color: "#212529",
                        fontVariantNumeric: "tabular-nums",
                      }}
                    >
                      {kD17Number}
                    </span>
<button
                        type="button"
                        aria-label="Copier"
                        title="Copier"
                        onClick={onCopy}
                        className="ip-ink"
                        style={{
                        appearance: "none",
                        border: 0,
                        background: "none",
                        cursor: "pointer",
                        color: "#FF923C",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        padding: 8,
                        borderRadius: 20,
                      }}
                    >
                      <MdContentCopy style={{ fontSize: 22 }} />
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}