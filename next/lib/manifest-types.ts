export interface DocumentLink {
  title: string;
  url: string;
}

export interface FolderSeoEntry {
  title: string;
  desc: string;
  path: string;
  docs: DocumentLink[];
}

export interface KeywordSeoEntry {
  title: string;
  desc: string;
}

export interface SeoManifest {
  canonicalBase: string;
  keywords: Record<string, KeywordSeoEntry>;
  folders: Record<string, FolderSeoEntry>;
}