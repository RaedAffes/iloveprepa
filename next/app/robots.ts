import type { MetadataRoute } from "next";
import { manifest } from "@/lib/manifest";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/view/"],
    },
    sitemap: `${manifest.canonicalBase}/sitemap.xml`,
    host: manifest.canonicalBase,
  };
}