const normalizeBaseUrl = (rawBaseUrl: string | undefined): string => {
  if (!rawBaseUrl) {
    return '';
  }

  return rawBaseUrl.replace(/\/+$/, '');
};

export const baseUrl = normalizeBaseUrl(import.meta.env.VITE_API_BASE_URL);

export class ApiError extends Error {
  readonly status: number;
  readonly body: unknown;

  constructor(message: string, status: number, body: unknown) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

type RequestOptions = {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  headers?: HeadersInit;
  body?: unknown;
  expectedStatuses?: number[];
};

const toAbsolutePath = (path: string): string => {
  if (!path.startsWith('/')) {
    return `/${path}`;
  }

  return path;
};

export const apiRequest = async <T>(path: string, options: RequestOptions = {}): Promise<T> => {
  const { method = 'GET', headers, body, expectedStatuses = [200] } = options;
  const requestHeaders = new Headers(headers);

  if (body !== undefined && !requestHeaders.has('Content-Type')) {
    requestHeaders.set('Content-Type', 'application/json');
  }

  const response = await fetch(`${baseUrl}${toAbsolutePath(path)}`, {
    method,
    headers: requestHeaders,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const contentType = response.headers.get('content-type') ?? '';
  const payload = contentType.includes('application/json')
    ? await response.json().catch(() => null)
    : await response.text().catch(() => '');

  if (!expectedStatuses.includes(response.status)) {
    throw new ApiError(
      `Request failed: ${method} ${path} (${response.status})`,
      response.status,
      payload,
    );
  }

  return payload as T;
};
