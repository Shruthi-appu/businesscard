import { randomBytes } from "crypto";

export type HttpSpanAttributes = {
  "http.method": string;
  "http.route": string;
  "http.status_code": number;
};

export function httpSpanAttributes(input: {
  method: string;
  path: string;
  statusCode: number;
}): HttpSpanAttributes {
  return {
    "http.method": input.method,
    "http.route": input.path,
    "http.status_code": input.statusCode,
  };
}

function headerPairs(raw: string): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const part of raw.split(",")) {
    const splitAt = part.indexOf("=");
    if (splitAt <= 0) continue;
    const key = part.slice(0, splitAt).trim();
    const value = part.slice(splitAt + 1).trim();
    if (key && value) headers[key] = value;
  }
  return headers;
}

export function emitHttpSpan(input: { method: string; path: string; statusCode: number }): void {
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT?.trim() ?? "";
  if (!endpoint) return;
  const attributes = httpSpanAttributes(input);
  const now = `${Date.now()}000000`;
  const body = JSON.stringify({
    resourceSpans: [
      {
        scopeSpans: [
          {
            spans: [
              {
                traceId: randomBytes(16).toString("hex"),
                spanId: randomBytes(8).toString("hex"),
                name: "http.request",
                kind: 2,
                startTimeUnixNano: now,
                endTimeUnixNano: now,
                attributes: [
                  { key: "http.method", value: { stringValue: attributes["http.method"] } },
                  { key: "http.route", value: { stringValue: attributes["http.route"] } },
                  { key: "http.status_code", value: { intValue: attributes["http.status_code"] } },
                ],
              },
            ],
          },
        ],
      },
    ],
  });
  const headers = {
    "content-type": "application/json",
    ...headerPairs(process.env.OTEL_EXPORTER_OTLP_HEADERS ?? ""),
  };
  void fetch(endpoint, { method: "POST", headers, body }).catch(() => undefined);
}
