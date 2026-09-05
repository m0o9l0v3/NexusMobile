import { expect, test, type Page } from '@playwright/test';
import { returnPath, tokenExpiresAt } from '../src/auth/token';

function jwt(expiresAt = Date.now() + 60_000, subject = 'admin') {
  return `header.${Buffer.from(JSON.stringify({ exp: Math.floor(expiresAt / 1000), sub: subject })).toString('base64url')}.signature`;
}

async function seedToken(page: Page, token: string) {
  await page.addInitScript((value) => localStorage.setItem('adminToken', value), token);
}

async function fillLogin(page: Page) {
  await page.getByLabel('ユーザー名').fill('admin');
  await page.getByLabel('パスワード', { exact: true }).fill('test-password');
  await page.getByRole('button', { name: 'ログイン', exact: true }).click();
}

test('JWT expiry parsing rejects malformed tokens and preserves expiry boundary', () => {
  expect(tokenExpiresAt(jwt(2_000))).toBe(2_000);
  for (const value of [null, '', 'not-a-token', 'a.b.c', 'a.bnVsbA.c', 'a.e30.c', 'a.eyJleHAiOiIxIn0.c']) {
    expect(tokenExpiresAt(value)).toBeNull();
  }
});

test('return destination accepts known routes only', () => {
  expect(returnPath({ from: '/events?day=1#details' })).toBe('/events?day=1#details');
  for (const from of ['https://example.com', '//example.com', '/\\example.com', '/login', '/missing', '/logs\n', 3, null]) {
    expect(returnPath({ from })).toBe('/');
  }
  expect(returnPath(null)).toBe('/');
});

test('all portal routes redirect unauthenticated users without exposing navigation', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  for (const route of ['/', '/spots', '/events', '/schedule', '/qr', '/logs', '/settings', '/unknown']) {
    await page.goto(route);
    await expect(page).toHaveURL(/\/login$/);
    await expect(page.getByRole('heading', { name: 'Nexus 管理ポータル' })).toBeVisible();
    await expect(page.getByRole('navigation')).toHaveCount(0);
    await expect(page.locator('vite-error-overlay')).toHaveCount(0);
  }
  expect(errors).toEqual([]);
});

test('login sends API contract and returns to deep link; logout clears token and cache', async ({ page }) => {
  const token = jwt();
  await page.route('**/admin/auth/login', async (route) => {
    expect(route.request().postDataJSON()).toEqual({ username: 'admin', password: 'test-password' });
    expect(route.request().headers()['content-type']).toContain('application/json');
    expect(route.request().headers()['authorization']).toBeUndefined();
    await route.fulfill({ json: { accessToken: token } });
  });
  await page.goto('/settings?tab=profile#main');
  await fillLogin(page);
  await expect(page).toHaveURL('/settings?tab=profile#main');
  expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBe(token);
  // Keep an earlier protected history entry; otherwise replace-navigation returns to about:blank.
  await page.goto('/logs');
  await expect(page.getByRole('button', { name: 'ログアウト', exact: true })).toBeVisible();
  await page.evaluate(async () => {
    const { queryClient } = await import('/src/api/queryClient.ts');
    queryClient.setQueryData(['private-test'], 'private');
  });
  await page.getByRole('button', { name: 'ログアウト', exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBeNull();
  expect(await page.evaluate(async () => (await import('/src/api/queryClient.ts')).queryClient.getQueryCache().getAll().length)).toBe(0);
  await page.goBack();
  await expect(page.getByRole('button', { name: 'ログイン', exact: true })).toBeVisible();
});

for (const failure of ['unauthorized', 'network', 'missing-token', 'expired-token', 'invalid-json'] as const) {
  test(`login handles ${failure} without entering portal`, async ({ page }) => {
    await page.route('**/admin/auth/login', async (route) => {
      if (failure === 'network') await route.abort();
      else if (failure === 'unauthorized') await route.fulfill({ status: 401, body: '' });
      else if (failure === 'invalid-json') await route.fulfill({ status: 200, contentType: 'application/json', body: 'bad-json' });
      else await route.fulfill({ json: failure === 'missing-token' ? {} : { accessToken: jwt(Date.now() - 10_000) } });
    });
    await page.goto('/login');
    await fillLogin(page);
    await expect(page.getByRole('alert')).toContainText('ログインできませんでした');
    await expect(page.getByLabel('パスワード', { exact: true })).toHaveValue('');
    await expect(page).toHaveURL('/login');
    expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBeNull();
  });
}

test('pending login disables duplicate submission', async ({ page }) => {
  let requests = 0;
  let finish!: () => void;
  const wait = new Promise<void>((resolve) => { finish = resolve; });
  await page.route('**/admin/auth/login', async (route) => {
    requests += 1;
    await wait;
    await route.fulfill({ status: 401, body: '' });
  });
  await page.goto('/login');
  await fillLogin(page);
  await expect(page.getByRole('button', { name: 'ログイン中…' })).toBeDisabled();
  await page.locator('form').evaluate((form: HTMLFormElement) => form.requestSubmit());
  expect(requests).toBe(1);
  finish();
  await expect(page.getByRole('alert')).toBeVisible();
});

for (const token of ['malformed', jwt(Date.now() - 10_000)]) {
  test(`stored ${token === 'malformed' ? 'malformed' : 'expired'} token redirects to login`, async ({ page }) => {
    await seedToken(page, token);
    await page.goto('/settings');
    await expect(page).toHaveURL('/login');
    expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBeNull();
  });
}

test('expiry removes open portal exactly at exp', async ({ page }) => {
  const now = new Date('2026-09-05T00:00:00Z');
  // Freeze before navigation so page loading does not consume part of the 10-second lifetime.
  await page.clock.install({ time: new Date(now.getTime() - 1_000) });
  await page.clock.pauseAt(now);
  await seedToken(page, jwt(now.getTime() + 10_000));
  await page.goto('/settings');
  await expect(page.getByRole('button', { name: 'ログアウト' })).toBeVisible();
  await page.clock.fastForward(9_999);
  await expect(page).toHaveURL('/settings');
  await page.clock.fastForward(1);
  await expect(page).toHaveURL('/login');
  expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBeNull();
});

test('logout in another tab redirects an open portal', async ({ page, context }) => {
  await seedToken(page, jwt());
  await page.goto('/settings');
  const other = await context.newPage();
  await other.goto('/settings');
  await other.getByRole('button', { name: 'ログアウト' }).click();
  await expect(page).toHaveURL('/login');
  await expect(other).toHaveURL('/login');
});

test('authenticated login route returns to dashboard and survives reload', async ({ page }) => {
  await seedToken(page, jwt());
  await page.goto('/login');
  await expect(page).toHaveURL('/');
  await page.reload();
  await expect(page.getByRole('button', { name: 'ログアウト' })).toBeVisible();
});

test('API adapter preserves Request body/header and 401 invalidates active session', async ({ page }) => {
  const token = jwt();
  await seedToken(page, token);
  await page.route('**/admin/spots', async (route) => {
    expect(route.request().headers()['authorization']).toBe(`Bearer ${token}`);
    expect(route.request().headers()['content-type']).toBe('application/json');
    expect(route.request().headers()['x-test']).toBe('kept');
    expect(route.request().postDataJSON()).toEqual({ name: 'test' });
    await route.fulfill({ status: 401, body: '' });
  });
  await page.goto('/settings');
  await page.evaluate(async () => {
    const { authenticatedFetch, baseUrl } = await import('/src/api/client.ts');
    await authenticatedFetch(new Request(`${baseUrl}/admin/spots`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Test': 'kept' }, body: JSON.stringify({ name: 'test' }),
    }));
  });
  await expect(page).toHaveURL('/login');
});

test('403 preserves session and late 401 cannot clear a newer token', async ({ page }) => {
  const initialToken = jwt();
  const nextToken = jwt(Date.now() + 60_000, 'other-admin');
  await seedToken(page, initialToken);
  await page.route('**/admin/spots', (route) => route.fulfill({ status: 403, body: '' }));
  await page.goto('/settings');
  await page.evaluate(async () => {
    const { apiClient } = await import('/src/api/client.ts');
    await apiClient.GET('/admin/spots');
  });
  await expect(page).toHaveURL('/settings');
  await page.route('**/admin/spots', async (route) => {
    await page.evaluate(async (token) => (await import('/src/auth/session.ts')).setAdminToken(token), nextToken);
    await route.fulfill({ status: 401, body: '' });
  });
  await page.evaluate(async () => (await import('/src/api/client.ts')).apiClient.GET('/admin/spots'));
  await expect(page).toHaveURL('/settings');
  expect(await page.evaluate(() => localStorage.getItem('adminToken'))).toBe(nextToken);
});
