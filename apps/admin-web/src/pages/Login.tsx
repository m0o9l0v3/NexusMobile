import { useRef, useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { login } from '../api/admin';
import { setAdminToken } from '../auth/session';
import { returnPath } from '../auth/token';
import { useAdminToken } from '../auth/useAdminToken';

export function Login() {
  const token = useAdminToken();
  const location = useLocation();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const submitting = useRef(false);

  if (token) return <Navigate to={returnPath(location.state)} replace />;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting.current || !username.trim() || !password) return;
    submitting.current = true;
    setPending(true);
    setError('');
    try {
      const data = await login({ username: username.trim(), password });
      if (!data?.accessToken) throw new Error('Missing access token');
      setAdminToken(data.accessToken);
    } catch {
      setError('ログインできませんでした。ユーザー名・パスワード、通信環境を確認して再度お試しください。');
      setPassword('');
    } finally {
      submitting.current = false;
      setPending(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-gradient-to-b from-background to-secondary p-6">
      <section aria-labelledby="login-title" className="w-full max-w-md rounded-[20px] border border-border bg-card p-6 shadow-sm">
        <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary text-xl font-bold text-primary-foreground" aria-hidden="true">N</div>
        <h1 id="login-title" className="text-2xl font-semibold text-foreground">Nexus 管理ポータル</h1>
        <p className="mt-4 text-sm text-muted-foreground">管理者アカウントでログインしてください。</p>
        <form onSubmit={handleSubmit} className="mt-5 space-y-4" aria-busy={pending}>
          <div>
            <label htmlFor="username" className="mb-2 block text-sm font-medium">ユーザー名</label>
            <input id="username" name="username" autoComplete="username" autoCapitalize="none" spellCheck={false} required value={username} onChange={(event) => setUsername(event.target.value)} disabled={pending} className="min-h-11 w-full rounded-2xl border border-border bg-card px-4 py-3 focus:outline-none focus:ring-2 focus:ring-primary" />
          </div>
          <div>
            <label htmlFor="password" className="mb-2 block text-sm font-medium">パスワード</label>
            <input id="password" name="password" type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} disabled={pending} className="min-h-11 w-full rounded-2xl border border-border bg-card px-4 py-3 focus:outline-none focus:ring-2 focus:ring-primary" />
          </div>
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <button type="submit" disabled={pending || !username.trim() || !password} className="min-h-11 w-full rounded-2xl bg-primary px-4 py-3 font-medium text-primary-foreground transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-60">
            {pending ? 'ログイン中…' : 'ログイン'}
          </button>
        </form>
      </section>
    </main>
  );
}
