export const DRIVE_FOLDER_ID = "1hf4Gr4ykqOmLovlYsb6C_IiC7NODN5sS";

export function driveViewUrl(id: string): string {
  return "https://drive.google.com/file/d/" + id + "/preview";
}

export function driveDownloadUrl(id: string): string {
  return "https://drive.google.com/uc?export=download&id=" + id;
}
