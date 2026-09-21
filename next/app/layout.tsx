import type { Metadata, Viewport } from "next";
import Script from "next/script";
import { inter, playfair, quicksand, cairo, pacifico } from "./fonts";
import { manifest } from "@/lib/manifest";
import BootSplash from "@/components/boot-splash";
import "./globals.css";

const home = manifest.keywords["iprepa"];

export const metadata: Metadata = {
  metadataBase: new URL(manifest.canonicalBase),
  title: {
    default: home?.title ?? "IlovePrepa : documents de prépa tunisienne gratuits",
    template: "%s | iPrepa",
  },
  description:
    home?.desc ??
    "Trouvez des documents de prépa en Tunisie : DS, examens, exercices et corrigés pour MP1, MP2 et les classes préparatoires.",
  applicationName: "IlovePrepa",
  manifest: "/manifest.json",
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "any" },
      { url: "/favicon.png", type: "image/png" },
      { url: "/favicon-16.png", type: "image/png", sizes: "16x16" },
    ],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180" }],
  },
  openGraph: {
    type: "website",
    siteName: "Document Prepa",
    locale: "fr_TN",
    images: ["/icons/Icon-512.png"],
  },
  twitter: {
    card: "summary",
    images: ["/icons/Icon-512.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  minimumScale: 0.5,
  maximumScale: 5,
  themeColor: "#1B3FA0",
  viewportFit: "cover",
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "iprepa",
  alternateName: "iPrepa",
  url: `${manifest.canonicalBase}/`,
  about:
    "Documents, DS, examens, exercices et corrigés pour les classes préparatoires tunisiennes, notamment MP1 et MP2",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="fr"
      className={`${inter.variable} ${playfair.variable} ${quicksand.variable} ${cairo.variable} ${pacifico.variable}`}
    >
      <head>
        <meta name="apple-mobile-web-app-title" content="iPrepa" />
        <meta name="mobile-web-app-capable" content="yes" />
      </head>
      <body>
        <BootSplash />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        {children}
        <Script
          src="https://static.cloudflareinsights.com/beacon.min.js"
          strategy="afterInteractive"
          data-cf-beacon='{"token":"0c80552a69c54e018793e2bb14fa0bf0"}'
        />
      </body>
    </html>
  );
}