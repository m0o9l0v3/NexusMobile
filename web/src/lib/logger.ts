import type { LogEvent } from "../types";
import { postLog } from "./api";

const SESSION_KEY = "nexus-session-id";
const QUEUE_KEY = "nexus-log-queue";

const randomId = (): string => crypto.randomUUID?.() ?? Math.random().toString(36).slice(2);

export const getSessionId = (): string => {
  const existing = localStorage.getItem(SESSION_KEY);
  if (existing) return existing;
  const id = randomId();
  localStorage.setItem(SESSION_KEY, id);
  return id;
};

const loadQueue = (): LogEvent[] => {
  try {
    const raw = localStorage.getItem(QUEUE_KEY);
    return raw ? (JSON.parse(raw) as LogEvent[]) : [];
  } catch (err) {
    console.error("log queue parse failed", err);
    return [];
  }
};

const saveQueue = (events: LogEvent[]) => {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(events));
};

let sending = false;

const flush = async () => {
  if (sending) return;
  const sessionId = getSessionId();
  const queue = loadQueue();
  if (!queue.length) return;
  sending = true;
  try {
    await postLog(sessionId, queue);
    saveQueue([]);
  } catch (err) {
    console.warn("log flush failed; will retry", err);
  } finally {
    sending = false;
  }
};

export const logEvent = (event: LogEvent) => {
  const queue = loadQueue();
  queue.push({ ...event, payload: event.payload ?? {}, type: event.type });
  saveQueue(queue);
  if (navigator.onLine) {
    void flush();
  }
};

export const setupLogRetry = () => {
  window.addEventListener("online", () => void flush());
  window.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") {
      void flush();
    }
  });
};
