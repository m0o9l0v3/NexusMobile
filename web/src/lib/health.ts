import { useCallback, useEffect, useState } from 'react';

/**
 * ブラウザから public-api の `/health` に届くかだけを調べる（#131）。
 * 応答の中身・版・構成は見ない。結果は「応答あり／応答なし」の2つだけ。
 */
export type HealthState = 'checking' | 'ok' | 'ng';

const TIMEOUT_MS = 8000;

export async function checkHealth(baseUrl: string | undefined): Promise<'ok' | 'ng'> {
  if (!baseUrl) return 'ng';
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${baseUrl.replace(/\/$/, '')}/health`, { cache: 'no-store', signal: ctrl.signal });
    return res.ok ? 'ok' : 'ng';
  } catch {
    return 'ng';
  } finally {
    clearTimeout(timer);
  }
}

export function useHealth() {
  const [state, setState] = useState<HealthState>('checking');
  const [checkedAt, setCheckedAt] = useState<Date | null>(null);

  const run = useCallback(async () => {
    setState('checking');
    const result = await checkHealth(import.meta.env.VITE_API_BASE_URL);
    setState(result);
    setCheckedAt(new Date());
  }, []);

  useEffect(() => {
    void run();
  }, [run]);

  return { state, checkedAt, recheck: run };
}
