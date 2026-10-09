# iloveprepa

A platform for preparatory school (prépa) content in Tunisia - sharing and hosting educational materials (courses, summaries, exercises, etc.).

## Overview

This project provides a web application to browse and access educational content organized hierarchically. It includes:
- **Next.js frontend** (in `next/`) - Modern web app with SSR/SSG capabilities
- **Flutter web app** (in `webapp/`) - Alternative Flutter-based web client
- **Cloudflare Worker** (in `worker/`) - API proxy for accessing content from Cloudflare R2 storage
- **Deployment tooling** - Build, prerendering, and deployment scripts for Cloudflare Pages

The app serves content stored in Cloudflare R2 (organized as folders/files under the `PrǸpa/` directory).

## Project Structure

```
iloveprepa/
├── deploy.bat          # Windows deployment script (builds Flutter app + prerenders SEO + deploys to Pages)
├── next/               # Next.js frontend
│   ├── app/            # Next.js App Router
│   ├── data/           # Generated SEO data (seo-manifest.json, keyword_meta.json)
│   ├── lib/            # Utilities (fetching from R2 worker API)
│   ├── scripts/        # Route generation, SEO prerendering
│   └── package.json
├── webapp/             # Flutter web application
│   ├── lib/            # Flutter app source
│   ├── tools/          # Build/prerender/fix tools (Python scripts)
│   ├── pubspec.yaml
│   └── web/            # Built assets
├── worker/             # Cloudflare Worker (API proxy to R2)
│   └── package.json
├── scripts/            # Utility scripts
│   └── friend-upload-python/  # Script for uploading files to R2
└── .gitignore
```

## Tech Stack

- **Next.js 16** (TypeScript, React 19) - Primary/secondary frontend
- **Flutter** - Web client
- **Cloudflare Workers** - Backend API proxy
- **Cloudflare R2** - File storage
- **Cloudflare Pages** - Hosting
- **Python** - Build/SEO/prerender tooling

## Getting Started

### Prerequisites

- Node.js (v18+)
- Flutter SDK (for building the Flutter web app)
- Python 3.x
- Wrangler CLI (`npm install -g wrangler` or use npx)

### Next.js Development

```bash
cd next
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the app.

Build for production:
```bash
cd next
npm run build
npm run start
```

Note: `prebuild` runs `scripts/gen-routes.mjs` which generates routes/SEO data from the R2 file listing.

### Flutter Web Development

```bash
cd webapp
flutter pub get
flutter run -d chrome
```

Build for production:
```bash
cd webapp
flutter build web --release --wasm --dart-define=API_BASE_URL=https://iloveprepa-r2.ilovepreparatoire.workers.dev
```

## Deployment

### Using deploy.bat (Windows)

The `deploy.bat` script automates the full Flutter deployment pipeline:
1. Generates folder SEO metadata + sitemap
2. Builds Flutter web app (with API base URL)
3. Prerenders SEO pages
4. Fixes Material icons (tree-shaking)
5. Switches to same-origin CanvasKit
6. Deploys to Cloudflare Pages (`iloveprepa.pages.dev`)

Run from project root:
```bat
deploy.bat
```

### Worker Deployment

```bash
cd worker
npm install
npx wrangler deploy
```

## File Uploading

The `scripts/friend-upload-python/` folder contains a utility to upload files to R2. See `scripts/friend-upload-python/README.txt` for detailed usage instructions (VS Code + Python).

**Note:** Credentials in `config.txt` should never be committed.

## API

The worker proxies requests to the R2 bucket. The API base URL is:  
`https://iloveprepa-r2.ilovepreparatoire.workers.dev`

See `worker/` source and generated route data for endpoint details.

## Live Site

- https://iloveprepa.pages.dev

## Repository

- GitHub: [RaedAffes/iloveprepa](https://github.com/RaedAffes/iloveprepa)

## Notes

- Large content directories (`PrǸpa/`, `PrǸpa.zip`, `/assets/`) are excluded from git (see `.gitignore`)
- The `next/` app depends on generated SEO data files (`data/seo-manifest.json`, `data/keyword_meta.json`) created by build scripts
- The Flutter build uses WASM for better performance
