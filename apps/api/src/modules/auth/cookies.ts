import type { Response } from "express";

import type { AppEnv } from "../../config/env";
import { headerValue, type RequestWithContext } from "../../common/request-context";

export const REFRESH_COOKIE = "softxu_refresh";

export function setRefreshCookie(res: Response, token: string, env: AppEnv): void {
  res.cookie(REFRESH_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: env.cookieSecure,
    path: "/",
    maxAge: env.REFRESH_TOKEN_TTL_SECONDS * 1000,
  });
}

export function clearRefreshCookie(res: Response, env: AppEnv): void {
  res.clearCookie(REFRESH_COOKIE, {
    httpOnly: true,
    sameSite: "lax",
    secure: env.cookieSecure,
    path: "/",
  });
}

export function readRefreshToken(req: RequestWithContext, bodyToken?: string): string {
  if (bodyToken && bodyToken.trim()) return bodyToken.trim();
  const cookie = req.cookies?.[REFRESH_COOKIE];
  return cookie?.trim() ?? "";
}

export function userAgentOf(req: RequestWithContext): string | undefined {
  return headerValue(req.headers["user-agent"]);
}
