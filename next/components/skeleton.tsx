"use client";

export function SkeletonCard() {
  return (
    <div className="ip-shimmer" style={{ padding: "14px 16px", background: "#FFFFFF", borderRadius: 16, border: "1px solid #E9E9E7", display: "flex", alignItems: "center" }}>
      <div style={{ width: 50, height: 50, borderRadius: 8, background: "#F7F7F5", flexShrink: 0 }} />
      <span style={{ width: 16 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8, minWidth: 0 }}>
        <div style={{ width: 200, height: 14, borderRadius: 8, background: "#F7F7F5", maxWidth: "100%" }} />
        <div style={{ width: 120, height: 10, borderRadius: 8, background: "#F7F7F5" }} />
      </div>
    </div>
  );
}

export function LoadingSkeleton() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      <SkeletonCard />
      <SkeletonCard />
      <SkeletonCard />
    </div>
  );
}