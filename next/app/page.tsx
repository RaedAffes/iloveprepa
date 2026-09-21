import { manifest } from "@/lib/manifest";
import Dashboard from "@/components/dashboard";

export default function HomePage() {
  const home = manifest.keywords["iprepa"];
  return (
    <>
      <div
        style={{
          position: "absolute",
          width: 1,
          height: 1,
          overflow: "hidden",
          clip: "rect(0 0 0 0)",
          whiteSpace: "nowrap",
        }}
      >
        <h1>Document Prepa</h1>
        <p>
          <strong>Documents Prépa</strong> en Tunisie : DS, examens, exercices
          et corrigés pour MP1, MP2 — {home?.desc ?? ""}
        </p>
      </div>
      <Dashboard />
    </>
  );
}