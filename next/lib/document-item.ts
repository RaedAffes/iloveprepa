export class ApiException extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ApiException";
  }
}

export class ServiceLockedException extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ServiceLockedException";
  }
}

export class RateLimitedException extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RateLimitedException";
  }
}

export interface DocumentItem {
  name: string;
  sizeBytes: number;
  uploadedAt?: number;
  contentType: string;
}

export function documentItemFromJson(json: Record<string, unknown>): DocumentItem {
  return {
    name: (json["name"] as string) ?? "",
    sizeBytes: Number(json["size"] ?? 0),
    uploadedAt:
      json["uploadTimestamp"] != null
        ? Number(json["uploadTimestamp"])
        : undefined,
    contentType: (json["contentType"] as string) ?? "application/octet-stream",
  };
}

export function documentItemToJson(doc: DocumentItem): Record<string, unknown> {
  return {
    name: doc.name,
    size: doc.sizeBytes,
    uploadTimestamp: doc.uploadedAt,
    contentType: doc.contentType,
  };
}

export function fileNameOf(doc: DocumentItem): string {
  return doc.name.split("/").pop() ?? "";
}

export function displayNameOf(doc: DocumentItem): string {
  let base = fileNameOf(doc);
  const dot = base.lastIndexOf(".");
  if (dot > 0) base = base.substring(0, dot);
  return base
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function extensionOf(doc: DocumentItem): string {
  const dot = fileNameOf(doc).lastIndexOf(".");
  return dot >= 0 ? fileNameOf(doc).substring(dot + 1).toLowerCase() : "";
}

export function folderOf(doc: DocumentItem): string {
  return doc.name.includes("/") ? doc.name.split("/")[0].trim() : "";
}

export function isPdfOf(doc: DocumentItem): boolean {
  return extensionOf(doc) === "pdf";
}

export function sizeLabelOf(sizeBytes: number): string {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (sizeBytes >= gb) return `${(sizeBytes / gb).toFixed(1)} GB`;
  if (sizeBytes >= mb) return `${(sizeBytes / mb).toFixed(1)} MB`;
  if (sizeBytes >= kb) return `${Math.round(sizeBytes / kb)} KB`;
  return `${sizeBytes} B`;
}