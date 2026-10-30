import { randomUUID } from "crypto";

import type { NextFunction, Response } from "express";
import { Logger } from "@nestjs/common";

export type AccessPrincipal = {
  id: string;
  role: "user" | "admin";
  email: string | null;
};

export type RequestWithContext = {
  requestId?: string;
  user?: AccessPrincipal;
  method: string;
  path: string;
  header(name: string): string | undefined;
  headers: Record<string, string | string[] | undefined>;
  ip?: string;
  cookies?: Record<string, string | undefined>;
  socket?: { remoteAddress?: string };
};

const logger = new Logger("http");

export function requestContextMiddleware(
  req: RequestWithContext,
  res: Response,
  next: NextFunction,
): void {
  const incoming = req.header("x-request-id");
  const requestId = incoming && /^[\w-]{1,80}$/.test(incoming) ? incoming : randomUUID();
  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);
  const started = Date.now();
  res.on("finish", () => {
    logger.log(
      `${req.method} ${req.path} ${res.statusCode} ${Date.now() - started}ms requestId=${requestId}`,
    );
  });
  next();
}

export function clientIp(req: RequestWithContext): string {
  return req.ip || req.socket?.remoteAddress || "unknown";
}

export function headerValue(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value;
}
