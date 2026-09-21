import { DocumentItem } from "./document-item";

export class LibraryFolder {
  constructor(
    public name: string,
    public children: Map<string, LibraryFolder> = new Map(),
    public files: DocumentItem[] = [],
  ) {}

  get isEmpty(): boolean {
    return this.children.size === 0 && this.files.length === 0;
  }

  get folderCount(): number {
    return this.children.size;
  }

  get fileCount(): number {
    return this.files.length;
  }

  get totalDocuments(): number {
    let total = this.files.length;
    for (const child of this.children.values()) {
      total += child.totalDocuments;
    }
    return total;
  }

  get totalSize(): number {
    let total = 0;
    for (const file of this.files) total += file.sizeBytes;
    for (const child of this.children.values()) total += child.totalSize;
    return total;
  }

  child(name: string): LibraryFolder | undefined {
    return this.children.get(name);
  }

  descend(path: string[]): LibraryFolder | undefined {
    const [first, ...rest] = path;
    if (!first) return this;
    const next = this.children.get(first);
    if (!next) return undefined;
    return next.descend(rest);
  }
}

export function buildLibraryTree(documents: DocumentItem[]): LibraryFolder {
  const root = new LibraryFolder("Library");

  for (const doc of documents) {
    const raw = doc.name.trim();
    if (!raw) continue;
    const isFolder = raw.endsWith("/");
    const parts = raw.split("/").filter((p) => p.trim().length > 0);
    if (parts.length === 0) continue;

    if (isFolder) {
      let node = root;
      for (const segment of parts) {
        const key = segment.trim();
        let next = node.children.get(key);
        if (!next) {
          next = new LibraryFolder(key);
          node.children.set(key, next);
        }
        node = next;
      }
      continue;
    }

    let node = root;
    for (let i = 0; i < parts.length - 1; i++) {
      const segment = parts[i].trim();
      let next = node.children.get(segment);
      if (!next) {
        next = new LibraryFolder(segment);
        node.children.set(segment, next);
      }
      node = next;
    }
    node.files.push(doc);
  }

  return root;
}