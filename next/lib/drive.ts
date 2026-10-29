import tree from "@/data/drive-tree.json";
import type { DocumentItem } from "./document-item";
import { displayNameOf, extensionOf } from "./document-item";

/**
 * Documents come from the Google Drive folder listed in data/drive-tree.json,
 * which is produced by `node scripts/gen-drive.mjs`. Every file keeps its Drive
 * id, so viewing/downloading points straight at Google Drive.
 */

interface DriveTreeFile {
  id: string;
  path: string[];
  modified?: string;
}

interface DriveTree {
  folderId: string;
  generatedAt: string;
  files: DriveTreeFile[];
}

const DRIVE_TREE = tree as unknown as DriveTree;

const MIME_BY_EXTENSION: Record<string, string> = {
  pdf: "application/pdf",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  gif: "image/gif",
  webp: "image/webp",
  txt: "text/plain",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ppt: "application/vnd.ms-powerpoint",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  xls: "application/vnd.ms-excel",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  mp4: "video/mp4",
  webm: "video/webm",
  mp3: "audio/mpeg",
  zip: "application/zip",
};

let cached: DocumentItem[] | null = null;

/** Flattened Drive listing, ready for LibraryIndex / search / sidebar. */
export function driveDocuments(): DocumentItem[] {
  if (cached) return cached;

  const documents: DocumentItem[] = DRIVE_TREE.files.map((file) => {
    const name = file.path.join("/");
    const extension = extensionOf({ name } as DocumentItem);
    return {
      name,
      sizeBytes: 0,
      contentType: MIME_BY_EXTENSION[extension] ?? "application/octet-stream",
      driveId: file.id,
    };
  });

  documents.sort((a, b) =>
    displayNameOf(a).toLowerCase().localeCompare(displayNameOf(b).toLowerCase()),
  );

  cached = documents;
  return cached;
}

export function isDriveDoc(doc: DocumentItem): boolean {
  return !!doc.driveId;
}

/**
 * The app hands out its own /view/<path> URLs; the route resolves the path to
 * the Drive file, so the Google link only ever exists server-side (and in the
 * redirect Location header).
 */
export function viewUrlForDoc(doc: DocumentItem): string {
  return `/view/${encodeURIComponent(doc.name)}`;
}

/** Bare redirect to Drive - the in-app viewer supplies its own chrome. */
export function rawViewUrlForDoc(doc: DocumentItem): string {
  return `/view/${encodeURIComponent(doc.name)}?raw=1`;
}

export function downloadUrlForDoc(doc: DocumentItem): string {
  return `/view/${encodeURIComponent(doc.name)}?download=1`;
}
