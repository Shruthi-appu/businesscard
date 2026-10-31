const SHARE = /^\/s\/[A-Za-z0-9_-]{20,200}$/;
const EXCHANGE = /^\/exchange\/[0-9a-f-]{36}(\?c=[A-Za-z0-9_-]{8,80})?$/;

export function safeReturnPath(next: string | null): string | null {
  if (!next) return null;
  if (SHARE.test(next) || EXCHANGE.test(next)) return next;
  return null;
}
