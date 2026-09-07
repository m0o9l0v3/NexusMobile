import type { TodayEventResponse } from '../src/types/events';

const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>();
const originalFetch = global.fetch;
const originalBaseUrl = process.env.EXPO_PUBLIC_API_BASE_URL;

beforeEach(() => {
  jest.resetModules();
  fetchMock.mockReset();
  global.fetch = fetchMock;
  process.env.EXPO_PUBLIC_API_BASE_URL = 'https://api.example.test///';
});

afterEach(() => {
  global.fetch = originalFetch;
  if (originalBaseUrl === undefined) {
    delete process.env.EXPO_PUBLIC_API_BASE_URL;
  } else {
    process.env.EXPO_PUBLIC_API_BASE_URL = originalBaseUrl;
  }
});

function respond(payload: TodayEventResponse[], status = 200) {
  const json = jest.fn().mockResolvedValue(payload);
  fetchMock.mockResolvedValue({ ok: status < 400, status, json } as unknown as Response);
  return json;
}

test('今日のイベントを取得し、APIの情報と画面用の補足情報を返す', async () => {
  // オフセットのない日時で端末ローカルの表示を検証し、実行環境のタイムゾーンに依存しない。
  respond([{
    id: 'orientation', title: '保護者説明会', startTime: '2026-09-05T10:15:00',
    endTime: '2026-09-05T11:00:00', location: '講義室', tags: ['学校説明'],
    description: '学費や学生生活について説明します。',
  }]);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');

  await expect(getTodayEvents()).resolves.toEqual([expect.objectContaining({
    id: 'orientation', title: '保護者説明会', time: '10:15', endTime: '11:00',
    location: '講義室', category: '学校説明', department: '全体',
    description: '学費や学生生活について説明します。', audience: '保護者', priority: 'support',
  })]);
  expect(fetchMock).toHaveBeenCalledTimes(1);
  expect(fetchMock).toHaveBeenCalledWith('https://api.example.test/api/events/today');
});

test('省略情報と不正な日時に表示用のフォールバックを使用する', async () => {
  respond([{ id: 'unknown', title: '案内', startTime: 'invalid', endTime: '' }]);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');
  await expect(getTodayEvents()).resolves.toEqual([expect.objectContaining({
    time: '--:--', endTime: '--:--', location: '会場未設定', category: 'イベント', description: '',
  })]);
});

test('URLが未設定なら開発用APIを使用し、空のレスポンスは空配列で返す', async () => {
  delete process.env.EXPO_PUBLIC_API_BASE_URL;
  respond([]);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');
  await expect(getTodayEvents()).resolves.toEqual([]);
  expect(fetchMock).toHaveBeenCalledWith('http://localhost:5001/api/events/today');
});

test('HTTPエラーでは成功データに変換せずステータスを含むエラーを返す', async () => {
  const json = respond([], 503);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');
  await expect(getTodayEvents()).rejects.toThrow('Request failed: 503');
  expect(json).not.toHaveBeenCalled();
});

test('接続失敗を呼び出し元へ返す', async () => {
  const error = new TypeError('Network request failed');
  fetchMock.mockRejectedValue(error);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');
  await expect(getTodayEvents()).rejects.toBe(error);
});

test('JSON解析失敗を呼び出し元へ返す', async () => {
  const error = new SyntaxError('Invalid JSON');
  fetchMock.mockResolvedValue({ ok: true, json: jest.fn().mockRejectedValue(error) } as unknown as Response);
  const { getTodayEvents } = jest.requireActual<typeof import('../src/api/events')>('../src/api/events');
  await expect(getTodayEvents()).rejects.toBe(error);
});
