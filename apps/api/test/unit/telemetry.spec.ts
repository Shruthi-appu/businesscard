import { emitHttpSpan, httpSpanAttributes } from "../../src/telemetry";
import { redactSharePath } from "../../src/common/request-context";

describe("http spans", () => {
  const originalEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  const originalFetch = global.fetch;

  afterEach(() => {
    if (originalEndpoint === undefined) delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
    else process.env.OTEL_EXPORTER_OTLP_ENDPOINT = originalEndpoint;
    global.fetch = originalFetch;
  });

  it("records method, redacted path, and status only", () => {
    const attributes = httpSpanAttributes({
      method: "GET",
      path: redactSharePath("/v1/public/shares/abcdefghijklmnop"),
      statusCode: 200,
    });
    const encoded = JSON.stringify(attributes);
    expect(encoded).not.toContain("ada@example.com");
    expect(encoded).not.toContain("Bearer");
    expect(encoded).not.toContain("+14155550195");
    expect(attributes["http.route"]).toBe("/v1/public/shares/abcd");
    expect(Object.keys(attributes).sort()).toEqual([
      "http.method",
      "http.route",
      "http.status_code",
    ]);
  });

  it("does not export when the collector endpoint is empty", () => {
    const fetchMock = jest.fn();
    global.fetch = fetchMock as unknown as typeof fetch;
    delete process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
    emitHttpSpan({
      method: "POST",
      path: "/v1/me/export",
      statusCode: 200,
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
