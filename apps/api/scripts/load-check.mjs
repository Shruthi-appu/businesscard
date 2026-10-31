const base = (process.env.API_ORIGIN ?? "http://127.0.0.1:3001").replace(/\/$/, "");
const email = `load.${Date.now()}@example.com`;
const password = "correct-horse";

async function send(path, init = {}) {
  const response = await fetch(`${base}${path}`, init);
  const text = await response.text();
  let body = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  return { status: response.status, body };
}

function percentile(samples, p) {
  const sorted = [...samples].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[Math.max(0, index)];
}

async function timed(run) {
  const started = performance.now();
  const result = await run();
  return { ms: performance.now() - started, status: result.status };
}

const registered = await send("/v1/auth/register", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ email, password, displayName: "Load Check" }),
});
if (registered.status !== 201) {
  console.error(`register failed ${registered.status}`);
  process.exit(1);
}
const token = registered.body.accessToken;
const headers = { authorization: `Bearer ${token}`, "content-type": "application/json" };
const created = await send("/v1/cards", {
  method: "POST",
  headers,
  body: JSON.stringify({
    title: "Load card",
    contacts: [{ kind: "name", value: "Load Check", isPrimary: true }],
  }),
});
if (created.status !== 201) {
  console.error(`create card failed ${created.status}`);
  process.exit(1);
}

async function burst(label, run, count) {
  const results = await Promise.all(Array.from({ length: count }, () => timed(run)));
  const errors = results.filter((result) => result.status < 200 || result.status >= 300);
  const samples = results.map((result) => result.ms);
  console.log(
    `${label} n=${count} errors=${errors.length} p95=${percentile(samples, 95).toFixed(1)}ms`,
  );
  return errors.length;
}

const listErrors = await burst("GET /v1/cards", () => send("/v1/cards", { headers }), 20);
const presignErrors = await burst(
  "POST /v1/assets/presign",
  () =>
    send("/v1/assets/presign", {
      method: "POST",
      headers,
      body: JSON.stringify({
        purpose: "logo",
        mimeType: "image/png",
        byteSize: 32,
        checksumSha256: "ab".repeat(32),
      }),
    }),
  20,
);

if (listErrors + presignErrors > 0) process.exit(1);
