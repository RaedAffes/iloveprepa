import type { MetadataRoute } from "next";
import { manifest } from "@/lib/manifest";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = manifest.canonicalBase;
  const urls: MetadataRoute.Sitemap = [
    {
      url: `${base}/`,
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 1,
    },
  ];

  const seen = new Set<string>([`${base}/`]);
  const add = (slug: string, priority: number) => {
    const url = `${base}/${slug}/`;
    if (seen.has(url)) return;
    seen.add(url);
    urls.push({ url, lastModified: new Date(), changeFrequency: "weekly", priority });
  };

  for (const slug of Object.keys(manifest.keywords).sort()) add(slug, 0.7);
  for (const slug of Object.keys(manifest.folders).sort()) add(slug, 0.6);

  return urls;
}