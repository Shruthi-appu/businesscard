import {
  authResponseSchema,
  cardListResponseSchema,
  meResponseSchema,
  problemSchema,
  type AuthResponse,
  type CardListResponse,
  type MeResponse,
  type Problem,
} from "@softxu/contracts";

export class ApiError extends Error {
  constructor(
    readonly problem: Problem,
    readonly network = false,
  ) {
    super(problem.title);
  }

  get status(): number {
    return this.problem.status;
  }
}

export function fieldErrorMap(problem: Problem | null): Record<string, string> {
  const errors: Record<string, string> = {};
  for (const error of problem?.errors ?? []) {
    errors[error.field] = error.message;
  }
  return errors;
}

async function parseBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return null;
  }
}

export async function apiSend(
  path: string,
  init: RequestInit & { token?: string | null } = {},
): Promise<unknown> {
  let response: Response;
  try {
    response = await fetch(`/api${path}`, {
      ...init,
      credentials: "include",
      headers: {
        "content-type": "application/json",
        ...(init.token ? { authorization: `Bearer ${init.token}` } : {}),
        ...(init.headers ?? {}),
      },
    });
  } catch {
    throw new ApiError(
      { type: "about:blank", title: "Network failure", status: 0, code: "network_failure" },
      true,
    );
  }
  const body = await parseBody(response);
  if (!response.ok) {
    const parsed = problemSchema.safeParse(body);
    throw new ApiError(
      parsed.success
        ? parsed.data
        : {
            type: "about:blank",
            title: "Request failed",
            status: response.status,
            code: response.status === 403 ? "forbidden" : "request_error",
          },
    );
  }
  return body;
}

function parseWith<T>(schema: { parse: (value: unknown) => T }, body: unknown): T {
  try {
    return schema.parse(body);
  } catch {
    throw new ApiError(
      { type: "about:blank", title: "Unexpected response", status: 0, code: "network_failure" },
      true,
    );
  }
}

export async function registerAccount(input: {
  email: string;
  password: string;
  displayName: string;
}): Promise<AuthResponse> {
  const body = await apiSend("/v1/auth/register", { method: "POST", body: JSON.stringify(input) });
  return parseWith(authResponseSchema, body);
}

export async function loginAccount(input: {
  email: string;
  password: string;
}): Promise<AuthResponse> {
  const body = await apiSend("/v1/auth/login", { method: "POST", body: JSON.stringify(input) });
  return parseWith(authResponseSchema, body);
}

export async function refreshSession(): Promise<AuthResponse | null> {
  try {
    const body = await apiSend("/v1/auth/refresh", { method: "POST", body: "{}" });
    return parseWith(authResponseSchema, body);
  } catch (error) {
    if (error instanceof ApiError && error.network) throw error;
    return null;
  }
}

export async function logoutSession(token: string | null): Promise<void> {
  await apiSend("/v1/auth/logout", { method: "POST", body: "{}", token });
}

export async function loadMe(token: string): Promise<MeResponse> {
  return parseWith(meResponseSchema, await apiSend("/v1/me", { token }));
}

export async function loadCards(
  token: string,
  query = "",
  filter = "all",
): Promise<CardListResponse> {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (filter && filter !== "all") params.set("filter", filter);
  const suffix = params.toString();
  const path = suffix ? `/v1/cards?${suffix}` : "/v1/cards";
  return parseWith(cardListResponseSchema, await apiSend(path, { token }));
}

export type JobCounts = {
  ocr: Record<string, number>;
  exports: Record<string, number>;
  pendingDeletion: number;
};

export async function exportAccount(token: string): Promise<{ id: string; status: string }> {
  const body = await apiSend("/v1/me/export", {
    method: "POST",
    token,
    headers: { "idempotency-key": crypto.randomUUID() },
  });
  return body as { id: string; status: string };
}

export async function downloadExport(token: string, id: string): Promise<Blob> {
  let response: Response;
  try {
    response = await fetch(`/api/v1/me/exports/${id}/file`, {
      headers: { authorization: `Bearer ${token}` },
    });
  } catch {
    throw new ApiError(
      { type: "about:blank", title: "Network failure", status: 0, code: "network_failure" },
      true,
    );
  }
  if (!response.ok) {
    const body = await parseBody(response);
    const parsed = problemSchema.safeParse(body);
    throw new ApiError(
      parsed.success
        ? parsed.data
        : {
            type: "about:blank",
            title: "Request failed",
            status: response.status,
            code: "request_error",
          },
    );
  }
  return response.blob();
}

export async function deleteAccount(token: string): Promise<void> {
  await apiSend("/v1/me/delete", {
    method: "POST",
    token,
    headers: { "idempotency-key": crypto.randomUUID() },
    body: JSON.stringify({ confirm: true }),
  });
}

export async function loadJobCounts(token: string): Promise<JobCounts> {
  const body = await apiSend("/v1/admin/jobs", { token });
  return body as JobCounts;
}

export async function createCard(
  token: string,
  input: { title: string; name: string; email: string; phone: string; company: string },
): Promise<{ id: string }> {
  const contacts = [
    input.name ? { kind: "name", value: input.name, isPrimary: true } : null,
    input.email ? { kind: "email", value: input.email } : null,
    input.phone ? { kind: "phone", value: input.phone } : null,
    input.company ? { kind: "company", value: input.company } : null,
  ].filter((row) => row !== null);
  const body = await apiSend("/v1/cards", {
    method: "POST",
    token,
    body: JSON.stringify({ title: input.title, contacts }),
  });
  return body as { id: string };
}
