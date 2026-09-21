"use client";

import { MdRefresh, MdCloudOff, MdFolderOpen, MdEngineering, MdCloudQueue, MdSearchOff } from "react-icons/md";
import { palette } from "@/lib/tokens";

export function OrangePillButton({
  label,
  onTap,
}: {
  label: string;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onTap}
      className="ff-quicksand"
      style={{
        appearance: "none",
        border: 0,
        cursor: "pointer",
        alignSelf: "center",
        padding: "16px 36px",
        borderRadius: 48,
        background: "#FF923C",
        color: "#FFFFFF",
        fontWeight: 700,
        fontSize: 16,
        transition: "background 0.15s ease",
      }}
      onMouseEnter={(e) => (e.currentTarget.style.background = "#FF7F1F")}
      onMouseLeave={(e) => (e.currentTarget.style.background = "#FF923C")}
    >
      {label}
    </button>
  );
}

function StatePanel({
  icon,
  iconColor,
  iconBg,
  title,
  subtitle,
  action,
}: {
  icon: React.ReactNode;
  iconColor: string;
  iconBg: string;
  title: string;
  subtitle: string;
  action?: React.ReactNode;
}) {
  return (
    <div style={{ display: "flex", justifyContent: "center", padding: 40 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", maxWidth: 460 }}>
        <div
          style={{
            width: 80,
            height: 80,
            borderRadius: 22,
            background: iconBg,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            color: iconColor,
          }}
        >
          {icon}
        </div>
        <div style={{ height: 24 }} />
        <h2 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: palette.darkCharcoal, textAlign: "center" }}>
          {title}
        </h2>
        <div style={{ height: 8 }} />
        <p style={{ margin: 0, maxWidth: 420, textAlign: "center", fontSize: 14, color: palette.secondary, lineHeight: 1.5 }}>
          {subtitle}
        </p>
        {action && (
          <>
            <div style={{ height: 24 }} />
            {action}
          </>
        )}
      </div>
    </div>
  );
}

function quicksand(type: React.ReactNode) {
  return <span className="ff-quicksand">{type}</span>;
}

export function ComeBackLaterView({ onRetry }: { onRetry: () => void }) {
  return (
    <div style={{ display: "flex", justifyContent: "center", alignItems: "center", padding: "24px" }}>
      <div style={{ maxWidth: 460, display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center" }}>
        <img src="/icons/check.png" alt="" height={280} style={{ objectFit: "contain" }} />
        <div style={{ height: 26 }} />
        <p
          className="ff-quicksand"
          style={{
            margin: 0,
            fontWeight: 600,
            fontSize: 17,
            lineHeight: 1.5,
            color: "#555A66",
          }}
        >
          {"Iloveprepa utilise des services totalement gratuits. Lorsqu'un grand nombre de personnes se connectent en même temps, la limite de ces services peut être atteinte. Merci de revenir après un moment "}
          <span style={{ color: "#FF5A6A" }}>♥</span>
        </p>
        <div style={{ height: 30 }} />
        <OrangePillButton label="Réessayer" onTap={onRetry} />
      </div>
    </div>
  );
}

export function ErrorView({
  onRetry,
  detail,
  apiBase,
}: {
  onRetry: () => void;
  detail?: string;
  apiBase?: string;
}) {
  const subtitle = detail
    ? `Une erreur est survenue lors de la connexion au serveur de documents :\n${detail}${apiBase ? `\n\nAPI : ${apiBase}` : ""}`
    : "Une erreur est survenue lors de la connexion au serveur de documents. Vérifiez votre connexion et réessayez.";
  return (
    <StatePanel
      icon={<MdCloudOff size={34} />}
      iconColor={palette.danger}
      iconBg={palette.dangerSoft}
      title="Impossible de joindre la bibliothèque"
      subtitle={subtitle}
      action={
        <button
          type="button"
          onClick={onRetry}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            appearance: "none",
            border: 0,
            cursor: "pointer",
            padding: "10px 18px",
            borderRadius: 12,
            background: "#1B3FA0",
            color: "#fff",
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          <MdRefresh size={17} /> Réessayer
        </button>
      }
    />
  );
}

export function EmptyView({ onRefresh }: { onRefresh: () => void }) {
  return (
    <StatePanel
      icon={<MdFolderOpen size={34} />}
      iconColor="#2F6FED"
      iconBg="#E8EDFA"
      title="Aucun document pour le moment"
      subtitle="Votre bibliothèque est vide. Ajoutez des fichiers à votre bucket R2 et ils apparaîtront ici."
      action={
        <button
          type="button"
          onClick={onRefresh}
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            appearance: "none",
            border: 0,
            cursor: "pointer",
            padding: "10px 18px",
            borderRadius: 12,
            background: "#1B3FA0",
            color: "#fff",
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          <MdRefresh size={17} /> Actualiser
        </button>
      }
    />
  );
}

export function LibraryMaintenanceView({ onRetry }: { onRetry: () => void }) {
  return (
    <StatePanel
      icon={<MdEngineering size={34} />}
      iconColor="#E88F2A"
      iconBg="#FFF3E0"
      title="Bibliothèque en cours de réglage"
      subtitle="La bibliothèque est maintenant en cours de réglage, merci de revenir une autre fois."
      action={quicksand(<OrangePillButton label="Réessayer" onTap={onRetry} />)}
    />
  );
}

export function ServerOverloadedView({ onRetry }: { onRetry: () => void }) {
  return (
    <StatePanel
      icon={<MdCloudQueue size={34} />}
      iconColor="#E88F2A"
      iconBg="#FFF3E0"
      title="Service temporairement indisponible"
      subtitle="Le serveur est temporairement surchargé ou bloqué. Merci de réessayer dans quelques instants."
      action={quicksand(<OrangePillButton label="Réessayer" onTap={onRetry} />)}
    />
  );
}

export function NoResultsView({ query }: { query: string }) {
  return (
    <StatePanel
      icon={<MdSearchOff size={34} />}
      iconColor="#2F6FED"
      iconBg="#E8EDFA"
      title="Aucun résultat"
      subtitle={`Aucun document ne correspond à « ${query} ». Essayez un autre mot.`}
    />
  );
}