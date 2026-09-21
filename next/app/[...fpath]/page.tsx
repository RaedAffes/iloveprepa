import type { Metadata } from "next";
import { manifest } from "@/lib/manifest";
import Dashboard from "@/components/dashboard";

export const dynamicParams = false;

interface PageProps {
  params: Promise<{ fpath: string[] }>;
}

const allSlugs = Array.from(
  new Set([...Object.keys(manifest.keywords), ...Object.keys(manifest.folders)]),
);

export function generateStaticParams() {
  return allSlugs.map((slug) => ({
    fpath: slug.split("/"),
  }));
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { fpath } = await params;
  const slug = fpath.join("/");
  const base = manifest.canonicalBase;

  const folder = manifest.folders[slug];
  if (folder) {
    return {
      title: folder.title,
      description: folder.desc,
      alternates: { canonical: `${base}/${slug}/` },
    };
  }

  const keyword = manifest.keywords[slug];
  if (keyword) {
    return {
      title: { absolute: keyword.title },
      description: keyword.desc,
      alternates: { canonical: `${base}/${slug}/` },
    };
  }

  return {};
}

export default async function FolderPage({ params }: PageProps) {
  const { fpath } = await params;
  const slug = fpath.join("/");
  const folder = manifest.folders[slug];

  const initialPath = folder ? folder.path.split("/").filter(Boolean) : null;

  return (
    <>
      {folder && (
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
          <h1>{folder.title}</h1>
          <p>{folder.desc}</p>
          {folder.docs.length > 0 && (
            <ul>
              {folder.docs.map((doc) => (
                <li key={doc.url}>
                  <a href={doc.url}>{doc.title}</a>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
      <Dashboard initialPath={initialPath} />
    </>
  );
}