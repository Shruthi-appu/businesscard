import type { FormEvent } from "react";

import { ValidationState } from "./states";

type FieldErrors = Record<string, string>;

export function RegisterForm({
  pending,
  fieldErrors,
  formError,
  onSubmit,
}: {
  pending: boolean;
  fieldErrors: FieldErrors;
  formError: string | null;
  onSubmit: (input: { email: string; password: string; displayName: string }) => void;
}) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    onSubmit({
      email: String(data.get("email") ?? ""),
      password: String(data.get("password") ?? ""),
      displayName: String(data.get("displayName") ?? ""),
    });
  }

  return (
    <form onSubmit={handleSubmit} aria-busy={pending}>
      {formError ? <ValidationState message={formError} /> : null}
      <label>
        Display name
        <input name="displayName" autoComplete="name" required />
        {fieldErrors.displayName ? <span role="alert">{fieldErrors.displayName}</span> : null}
      </label>
      <label>
        Email
        <input name="email" type="email" autoComplete="email" required />
        {fieldErrors.email ? <span role="alert">{fieldErrors.email}</span> : null}
      </label>
      <label>
        Password
        <input name="password" type="password" autoComplete="new-password" minLength={8} required />
        {fieldErrors.password ? <span role="alert">{fieldErrors.password}</span> : null}
      </label>
      <button type="submit" disabled={pending}>
        {pending ? "Creating account…" : "Create account"}
      </button>
    </form>
  );
}

export function LoginForm({
  pending,
  fieldErrors,
  formError,
  onSubmit,
}: {
  pending: boolean;
  fieldErrors: FieldErrors;
  formError: string | null;
  onSubmit: (input: { email: string; password: string }) => void;
}) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    onSubmit({
      email: String(data.get("email") ?? ""),
      password: String(data.get("password") ?? ""),
    });
  }

  return (
    <form onSubmit={handleSubmit} aria-busy={pending}>
      {formError ? <ValidationState message={formError} /> : null}
      <label>
        Email
        <input name="email" type="email" autoComplete="email" required />
        {fieldErrors.email ? <span role="alert">{fieldErrors.email}</span> : null}
      </label>
      <label>
        Password
        <input name="password" type="password" autoComplete="current-password" required />
        {fieldErrors.password ? <span role="alert">{fieldErrors.password}</span> : null}
      </label>
      <button type="submit" disabled={pending}>
        {pending ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
