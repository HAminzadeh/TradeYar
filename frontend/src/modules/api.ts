export type Json = any;

export async function api(path: string, init?: RequestInit): Promise<Json> {
  const response = await fetch(path, {
    ...init,
    headers: { 'Accept': 'application/json', ...(init?.body ? {'Content-Type': 'application/json'} : {}), ...init?.headers },
  });
  const content = await response.text();
  let parsed: Json = null;
  try { parsed = content ? JSON.parse(content) : null; } catch { parsed = content; }
  if (!response.ok) {
    const message = typeof parsed === 'object' && parsed ? (parsed.error || parsed.message || parsed.detail) : String(parsed ?? '');
    throw new Error(`HTTP ${response.status}${message ? ': ' + message : ''}`);
  }
  return parsed;
}

export function post(path: string, body: unknown): Promise<Json> {
  return api(path, { method: 'POST', body: JSON.stringify(body) });
}

export function put(path: string, body: unknown): Promise<Json> {
  return api(path, { method: 'PUT', body: JSON.stringify(body) });
}

export function pretty(value: unknown): string { return JSON.stringify(value, null, 2); }
