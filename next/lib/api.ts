"use client";

import {
  ApiException,
  ServiceLockedException,
  RateLimitedException,
  DocumentItem,
  documentItemFromJson,
  displayNameOf,
} from "./document-item";
import { API_BASE, EMAIL_JS_SERVICE_ID, EMAIL_JS_PUBLIC_KEY, EMAIL_JS_TEMPLATE_ID } from "./config";

async function getJson(url: string, timeoutMs = 10000): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchDocuments(): Promise<DocumentItem[]> {
  const response = await getJson(`${API_BASE}/api/files`);
  if (response.status !== 200) {
    if (response.status === 503) {
      let body: Record<string, unknown> = {};
      try {
        body = await response.json();
      } catch {
        /* ignore */
      }
      if (body["locked"] === true) {
        throw new ServiceLockedException(
          (body["error"] as string) ?? "Service temporarily paused",
        );
      }
    }
    if (response.status === 429) {
      throw new RateLimitedException(
        "Le serveur est temporairement surchargé. Merci de réessayer dans quelques instants.",
      );
    }
    throw new ApiException(
      `Le serveur a répondu avec le code ${response.status}`,
    );
  }
  const body = (await response.json()) as { files?: Record<string, unknown>[] };
  const files = (body["files"] ?? []).map((e) => documentItemFromJson(e));
  files.sort((a, b) =>
    displayNameOf(a).toLowerCase().localeCompare(displayNameOf(b).toLowerCase()),
  );
  return files;
}

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export async function validateEmail(email: string): Promise<boolean> {
  const trimmed = email.trim();
  if (!EMAIL_RE.test(trimmed)) return false;
  try {
    const url = `${API_BASE}/api/validate-email?email=${encodeURIComponent(trimmed)}`;
    const response = await getJson(url);
    if (response.status !== 200) return true;
    const body = (await response.json()) as { ok?: boolean };
    return body["ok"] === true;
  } catch {
    return true;
  }
}

export async function sendContact(params: {
  name: string;
  email: string;
  message: string;
}): Promise<void> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20000);
  let response: Response;
  try {
    response = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        service_id: EMAIL_JS_SERVICE_ID,
        template_id: EMAIL_JS_TEMPLATE_ID,
        user_id: EMAIL_JS_PUBLIC_KEY,
        template_params: params,
      }),
    });
  } finally {
    clearTimeout(timer);
  }
  if (response.status !== 200) {
    throw new ApiException(
      `Impossible d'envoyer le message (code ${response.status}). Veuillez réessayer.`,
    );
  }
}