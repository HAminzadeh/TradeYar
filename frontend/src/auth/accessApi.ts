/** Cookie-based auth client. Never store session tokens or passwords in localStorage. */
export type UserRole = 'ADMIN' | 'RESEARCH_MANAGER' | 'ANALYST' | 'VIEWER';
export type UserStatus = 'PENDING' | 'ACTIVE' | 'SUSPENDED';
export type Permission = 'USER_MANAGE' | 'RESEARCH_READ' | 'RESEARCH_RUN' | 'PAPER_TRADE' | 'AUDIT_READ';
export type AccessUser = {
  id: string; username: string; displayName: string; email: string | null;
  role: UserRole; status: UserStatus; permissions: Permission[];
  lastLoginAt: string | null; lockedUntil?: string | null;
};
export type AccessStatus = { enabled: boolean; configured: boolean };
export type RegistrationResponse = { message: string; status: UserStatus };
export type LoginResponse = { user: AccessUser };

function readCookie(name: string): string | null {
  const pair = document.cookie.split(';').map(c => c.trim()).find(c => c.startsWith(`${name}=`));
  return pair ? decodeURIComponent(pair.substring(name.length + 1)) : null;
}
export class AccessError extends Error {
  constructor(public status: number, message: string) { super(message); this.name = 'AccessError'; }
}
export async function accessApi<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method || 'GET').toUpperCase();
  const headers = new Headers(init.headers);
  if (init.body && !headers.has('Content-Type')) headers.set('Content-Type','application/json');
  if (!['GET','HEAD','OPTIONS'].includes(method)) {
    const csrf = readCookie('tradeyar_csrf');
    if (csrf) headers.set('X-TradeYar-CSRF',csrf);
  }
  const response = await fetch(path,{...init,method,headers,credentials:'same-origin',cache:'no-store'});
  if (!response.ok) {
    let message = response.status === 401 ? 'لطفاً دوباره وارد شوید.' : `خطای ${response.status}`;
    try { const data = await response.json() as { message?:string; detail?:string }; message=data.message || data.detail || message; } catch { /* fallback */ }
    throw new AccessError(response.status,message);
  }
  if (response.status === 204) return undefined as T;
  return await response.json() as T;
}
