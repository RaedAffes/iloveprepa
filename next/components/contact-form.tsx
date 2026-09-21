"use client";

import { MdEdit, MdMailOutline, MdPersonOutline } from "react-icons/md";
import { useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import ContactIllustration from "@/components/contact-illustration";
import { validateEmail, sendContact } from "@/lib/api";

type Status = "idle" | "sending" | "success" | "error";

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const ARABIC_RE = /[\u0600-\u06FF]/;

const pill: CSSProperties = {
  display: "flex",
  alignItems: "center",
  gap: 10,
  borderRadius: 32,
  background: "#F2F6F8",
  border: "1.2px solid #DCE3E9",
  padding: "0 20px 0 16px",
  height: 57,
  flexShrink: 0,
};

const inputCss: CSSProperties = {
  flex: 1,
  border: 0,
  outline: "none",
  background: "transparent",
  fontFamily: "var(--font-quicksand)",
  fontWeight: 400,
  fontSize: 16,
  lineHeight: 1.3,
  color: "#212529",
  height: "100%",
  minWidth: 0,
  padding: 0,
};

export default function ContactForm() {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [resetKey, setResetKey] = useState(0);

  const rtl = ARABIC_RE.test(message);

  const ref = useRef<HTMLDivElement>(null);
  const [wide, setWide] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setWide(el.getBoundingClientRect().width >= 980);
    const obs = new ResizeObserver(() =>
      setWide(el.getBoundingClientRect().width >= 980),
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  const submit = async () => {
    if (status === "sending") return;
    const tName = name.trim();
    const tEmail = email.trim();
    const tMessage = message.trim();

    const fail = (msg: string) => {
      setError(msg);
      setStatus("error");
    };

    if (tName.length === 0) return fail("Veuillez saisir votre nom.");
    if (tEmail.length === 0) return fail("Veuillez saisir votre adresse e-mail.");
    if (!EMAIL_RE.test(tEmail)) return fail("Veuillez saisir une adresse e-mail valide.");
    if (tMessage.length === 0) return fail("Veuillez écrire votre message.");

    setError(null);
    setStatus("sending");
    try {
      const emailOk = await validateEmail(tEmail);
      if (!emailOk) {
        setError(
          "Cette adresse e-mail semble invalide (domaine inexistant). Veuillez en saisir une autre.",
        );
        setStatus("error");
        return;
      }
      await sendContact({ name: tName, email: tEmail, message: tMessage });
      setStatus("success");
    } catch {
      setError("Une erreur est survenue. Veuillez réessayer.");
      setStatus("error");
    }
  };

  const reset = () => {
    setName("");
    setEmail("");
    setMessage("");
    setError(null);
    setStatus("idle");
    setResetKey((k) => k + 1);
  };

  const successCard = (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        textAlign: "center",
      }}
    >
      <img src="/icons/check.png" alt="" style={{ height: 280, width: "auto" }} />
      <div style={{ height: 26 }} />
      <span
        style={{
          fontFamily: "var(--font-pacifico)",
          fontSize: 36,
          lineHeight: 1.1,
          color: "#212529",
        }}
      >
        Message envoyé !
      </span>
      <div style={{ height: 10 }} />
      <span
        style={{
          fontFamily: "var(--font-quicksand)",
          fontWeight: 600,
          fontSize: 15,
          lineHeight: 1.5,
          color: "#838788",
        }}
      >
        Merci pour votre message. Nous vous répondrons à votre adresse e-mail
        dans les plus brefs délais.
      </span>
      <div style={{ height: 28 }} />
      <button
        type="button"
        onClick={reset}
        style={{
          appearance: "none",
          border: 0,
          cursor: "pointer",
          height: 56,
          padding: "0 24px",
          borderRadius: 48,
          background: "#FF923C",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "var(--font-quicksand)",
          fontWeight: 600,
          fontSize: 16,
          color: "#FFFFFF",
        }}
      >
        Envoyer un autre message
      </button>
    </div>
  );

  const formFields = (
    <>
      <div style={{ width: "100%", textAlign: "center" }}>
        <span
          style={{
            fontFamily: "var(--font-pacifico)",
            fontSize: 36,
            lineHeight: 1.1,
            color: "#212529",
          }}
        >
          Talk to us
        </span>
      </div>
      <div style={{ height: 8 }} />
      <div style={pill}>
        <MdPersonOutline style={{ fontSize: 20, color: "#57565C", flexShrink: 0 }} />
        <input
          className="ip-field"
          style={inputCss}
          placeholder="Name"
          value={name}
          disabled={status === "sending"}
          onChange={(e) => setName(e.target.value)}
        />
      </div>
      <div style={{ height: 16 }} />
      <div style={pill}>
        <MdMailOutline style={{ fontSize: 20, color: "#57565C", flexShrink: 0 }} />
        <input
          className="ip-field"
          style={inputCss}
          placeholder="E-mail"
          type="email"
          value={email}
          disabled={status === "sending"}
          onChange={(e) => setEmail(e.target.value)}
        />
      </div>
      <div style={{ height: 16 }} />
      <div style={{ position: "relative", height: 150, flexShrink: 0 }}>
        <textarea
          key={resetKey}
          className="ip-field ip-message"
          style={{
            width: "100%",
            height: "100%",
            resize: "none",
            boxSizing: "border-box",
            border: "1.2px solid #DCE3E9",
            borderRadius: 32,
            background: "#F2F6F8",
            outline: "none",
            fontFamily: "var(--font-cairo)",
            fontWeight: 500,
            fontSize: 16,
            lineHeight: 1.5,
            color: "#212529",
            padding: rtl ? "16px 52px 16px 20px" : "16px 20px 16px 52px",
            direction: rtl ? "rtl" : "ltr",
            textAlign: rtl ? "right" : "left",
            whiteSpace: "pre-wrap",
          }}
          placeholder="Votre message…"
          value={message}
          disabled={status === "sending"}
          onChange={(e) => setMessage(e.target.value)}
        />
        <MdEdit
          style={{
            position: "absolute",
            top: 20,
            left: rtl ? undefined : 20,
            right: rtl ? 20 : undefined,
            fontSize: 20,
            color: "#57565C",
            pointerEvents: "none",
          }}
        />
      </div>
      <div style={{ height: 22 }} />
      <button
        type="button"
        onClick={submit}
        disabled={status === "sending"}
        style={{
          appearance: "none",
          border: 0,
          cursor: status === "sending" ? "default" : "pointer",
          height: 62,
          borderRadius: 48,
          background: "#FF923C",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "var(--font-quicksand)",
          fontWeight: 700,
          fontSize: 17,
          color: "#FFFFFF",
          padding: 0,
        }}
      >
        {status === "sending" ? (
          <svg
            width={22}
            height={22}
            viewBox="0 0 22 22"
            style={{ animation: "ip-spin 1s linear infinite" }}
            aria-hidden
          >
            <path
              d="M11 1a10 10 0 0 1 10 10"
              fill="none"
              stroke="#FFFFFF"
              strokeWidth={2.4}
              strokeLinecap="round"
            />
          </svg>
        ) : (
          "Send message"
        )}
      </button>
      {status === "error" && error && (
        <>
          <div style={{ height: 14 }} />
          <div
            style={{
              background: "#FDECEA",
              border: "1px solid #E0533D",
              borderRadius: 28,
              padding: "12px 14px",
              fontFamily: "var(--font-quicksand)",
              fontWeight: 600,
              fontSize: 13,
              color: "#B23B28",
              textAlign: "center",
            }}
          >
            {error}
          </div>
        </>
      )}
    </>
  );

  const form = (
    <div
      style={{
        width: "100%",
        maxWidth: 420,
        display: "flex",
        flexDirection: "column",
        flexShrink: 1,
        minWidth: 0,
      }}
    >
      {status === "success" ? successCard : formFields}
    </div>
  );

  return (
    <div
      ref={ref}
      style={{
        width: "100%",
        minHeight: "100%",
        background: "#F6F9FC",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 24,
        boxSizing: "border-box",
      }}
    >
      {wide ? (
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 12,
            width: "100%",
          }}
        >
          <div style={{ width: (368 * 790) / 563, flexShrink: 0 }}>
            <ContactIllustration />
          </div>
          {form}
        </div>
      ) : (
        <div style={{ position: "relative", width: "100%" }}>
          <div style={{ width: "100%", opacity: 0.28, pointerEvents: "none" }}>
            <ContactIllustration />
          </div>
          <div style={{ paddingTop: 170 }}>
            <div style={{ display: "flex", justifyContent: "center" }}>{form}</div>
          </div>
        </div>
      )}
    </div>
  );
}