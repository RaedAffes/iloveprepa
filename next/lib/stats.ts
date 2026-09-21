"use client";

import { API_BASE } from "./config";

export interface StatsCounters {
  visits: number;
  downloads: number;
}

interface Listener {
  (): void;
}

const EMPTY: StatsCounters = { visits: 0, downloads: 0 };

class StatsService {
  private _last: StatsCounters = { ...EMPTY };
  private listeners = new Set<Listener>();
  private started = false;

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    this.ensureStarted();
    return () => {
      this.listeners.delete(listener);
    };
  }

  getSnapshot(): StatsCounters {
    return this._last;
  }

  private ensureStarted(): void {
    if (this.started) return;
    this.started = true;
    void this.refresh();
    this.logAppOpen();
  }

  async refresh(): Promise<void> {
    try {
      const response = await fetch(`${API_BASE}/api/stats`);
      if (response.status !== 200) return;
      const data = (await response.json()) as {
        visits?: number;
        downloads?: number;
      };
      this._last = {
        visits: Number(data["visits"] ?? 0),
        downloads: Number(data["downloads"] ?? 0),
      };
      this.emit();
    } catch {
      /* best-effort */
    }
  }

  logAppOpen(): void {
    void this.increment({ visits: 1 });
  }

  logDownload(): void {
    void this.increment({ downloads: 1 });
  }

  private async increment(fields: Record<string, number>): Promise<void> {
    const next = { ...this._last };
    for (const key of Object.keys(fields)) {
      if (key === "visits" || key === "downloads") {
        next[key] += fields[key];
      }
    }
    this._last = next;
    this.emit();
    try {
      await fetch(`${API_BASE}/api/stats/increment`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(fields),
      });
    } catch {
      /* best-effort analytics */
    }
  }

  private emit(): void {
    for (const listener of this.listeners) {
      try {
        listener();
      } catch {
        /* ignore */
      }
    }
  }
}

export const statsService = new StatsService();

export function formatFr(n: number): string {
  try {
    return new Intl.NumberFormat("fr-FR").format(n);
  } catch {
    return String(n);
  }
}