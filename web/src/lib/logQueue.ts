import { postLog, postLogBatch, type CreateLogRequest } from '@/api/publicApi';

const SESSION_STORAGE_KEY = 'nexus.sessionId';
const LOG_QUEUE_STORAGE_KEY = 'nexus.logQueue';
const MAX_BATCH_SIZE = 50;

const safeWindow = typeof window !== 'undefined' ? window : undefined;

const uuid = (): string => {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }

  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
};

export const getSessionId = (): string => {
  if (!safeWindow) {
    return 'server-session';
  }

  const existing = safeWindow.localStorage.getItem(SESSION_STORAGE_KEY);
  if (existing) {
    return existing;
  }

  const next = uuid();
  safeWindow.localStorage.setItem(SESSION_STORAGE_KEY, next);
  return next;
};

const readQueue = (): CreateLogRequest[] => {
  if (!safeWindow) {
    return [];
  }

  const raw = safeWindow.localStorage.getItem(LOG_QUEUE_STORAGE_KEY);
  if (!raw) {
    return [];
  }

  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

const writeQueue = (items: CreateLogRequest[]): void => {
  if (!safeWindow) {
    return;
  }

  safeWindow.localStorage.setItem(LOG_QUEUE_STORAGE_KEY, JSON.stringify(items));
};

const chunk = <T>(items: T[], size: number): T[][] => {
  const result: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    result.push(items.slice(i, i + size));
  }

  return result;
};

export const enqueueLog = (input: Omit<CreateLogRequest, 'sessionId' | 'occurredAt'>): void => {
  const current = readQueue();
  current.push({
    ...input,
    sessionId: getSessionId(),
    occurredAt: new Date().toISOString(),
  });
  writeQueue(current);
};

export const flushLogs = async (): Promise<void> => {
  const queued = readQueue();
  if (queued.length === 0) {
    return;
  }

  if (queued.length === 1) {
    await postLog(queued[0]);
    writeQueue([]);
    return;
  }

  const groups = chunk(queued, MAX_BATCH_SIZE);
  for (const logs of groups) {
    await postLogBatch({ logs });
  }

  writeQueue([]);
};
