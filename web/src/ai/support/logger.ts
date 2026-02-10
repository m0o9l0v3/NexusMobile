import type { SupportEventName } from "@/ai/support/types";

type SupportLogEntry = {
  event: SupportEventName;
  timestamp: string;
  payload?: Record<string, unknown>;
};

const STORAGE_KEY = "nexus.support.logs.v1";
const MAX_ENTRIES = 100;

export function logSupportEvent(
  event: SupportEventName,
  payload?: Record<string, unknown>
) {
  const entry: SupportLogEntry = {
    event,
    timestamp: new Date().toISOString(),
    payload,
  };

  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const entries = raw ? (JSON.parse(raw) as SupportLogEntry[]) : [];
    entries.push(entry);
    const compacted = entries.slice(-MAX_ENTRIES);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(compacted));
  } catch {
    // Ignore storage errors (private mode, quota, etc.)
  }

  console.info("[support-event]", entry);
}
