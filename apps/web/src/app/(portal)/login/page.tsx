"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { LoginForm } from "@/components/auth-forms";
import { LoadingState, NetworkState } from "@/components/states";
import { ApiError, fieldErrorMap, loginAccount } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

export default function LoginPage() {
  const auth = useAuth();
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [network, setNetwork] = useState(false);

  useEffect(() => {
    if (auth.status === "ready") router.replace("/wallet");
  }, [auth.status, router]);

  if (auth.status === "loading" || auth.status === "ready") {
    return <LoadingState label="Checking your session…" />;
  }

  return (
    <section className="narrow panel">
      <h1>Sign in</h1>
      <p>Use the email and password for your Softxu account.</p>
      {network || auth.status === "network" ? <NetworkState onRetry={auth.retry} /> : null}
      <LoginForm
        pending={pending}
        fieldErrors={fieldErrors}
        formError={formError}
        onSubmit={async (input) => {
          setPending(true);
          setFormError(null);
          setFieldErrors({});
          setNetwork(false);
          try {
            const session = await loginAccount(input);
            auth.setSession(session.accessToken, session.user);
            router.push("/wallet");
          } catch (error) {
            if (error instanceof ApiError && error.network) {
              setNetwork(true);
            } else if (error instanceof ApiError && error.status === 400) {
              setFieldErrors(fieldErrorMap(error.problem));
              setFormError(error.problem.title);
            } else if (error instanceof ApiError) {
              setFormError(error.problem.title);
            } else {
              setNetwork(true);
            }
          } finally {
            setPending(false);
          }
        }}
      />
      <p>
        New here? <Link href="/register">Create an account</Link>
      </p>
    </section>
  );
}
