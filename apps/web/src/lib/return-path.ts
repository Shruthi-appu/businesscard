export function safeReturnPath(next: string | null): string | null {
  if (next && /^\/s\/[A-Za-z0-9_-]{20,200}$/.test(next)) return next;
  return null;
}
