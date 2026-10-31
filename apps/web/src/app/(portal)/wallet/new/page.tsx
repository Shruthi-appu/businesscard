"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { ValidationState } from "@/components/states";
import { ApiError, createCard, fieldErrorMap } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

export default function NewCardPage() {
  const auth = useAuth();
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  return (
    <section className="narrow panel">
      <h1>Add a card</h1>
      <p>Type the details. Nothing here is scanned.</p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (!auth.accessToken) return;
          const data = new FormData(event.currentTarget);
          setPending(true);
          setFormError(null);
          setFieldErrors({});
          void createCard(auth.accessToken, {
            title: String(data.get("title") ?? ""),
            name: String(data.get("name") ?? ""),
            email: String(data.get("email") ?? ""),
            phone: String(data.get("phone") ?? ""),
            company: String(data.get("company") ?? ""),
          })
            .then((card) => router.push(`/wallet/${card.id}`))
            .catch((error: unknown) => {
              if (error instanceof ApiError && error.status === 400) {
                setFieldErrors(fieldErrorMap(error.problem));
                setFormError(error.problem.title);
              } else if (error instanceof ApiError) {
                setFormError(error.problem.title);
              } else {
                setFormError("We couldn't reach Softxu. Check your connection and try again.");
              }
            })
            .finally(() => setPending(false));
        }}
      >
        {formError ? <ValidationState message={formError} /> : null}
        <label>
          Card title
          <input name="title" required />
        </label>
        <label>
          Name
          <input name="name" required />
          {fieldErrors["contacts.0.value"] ? (
            <span role="alert">{fieldErrors["contacts.0.value"]}</span>
          ) : null}
        </label>
        <label>
          Email
          <input name="email" type="email" />
        </label>
        <label>
          Phone
          <input name="phone" />
        </label>
        <label>
          Company
          <input name="company" />
        </label>
        <button type="submit" disabled={pending}>
          {pending ? "Saving…" : "Save card"}
        </button>
      </form>
    </section>
  );
}
