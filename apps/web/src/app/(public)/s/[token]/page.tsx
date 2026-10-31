"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { LoadingState, NetworkState, ValidationState } from "@/components/states";
import { ApiError, apiSend } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type Preview = {
  pinRequired: boolean;
  expiresAt?: string;
  senderName?: string;
  title?: string;
  contacts?: Array<{ kind: string; value: string; href: string | null }>;
  addresses?: string[];
  socials?: Array<{ platform: string; url: string }>;
};

export default function SharePage() {
  const params = useParams<{ token: string }>();
  const token = params.token;
  const auth = useAuth();
  const router = useRouter();
  const [preview, setPreview] = useState<Preview | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "pin" | "gone" | "network">("loading");
  const [pin, setPin] = useState("");
  const [consent, setConsent] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function load(nextPin?: string) {
    setPending(true);
    setError(null);
    void apiSend(`/v1/public/shares/${encodeURIComponent(token)}`, {
      headers: nextPin ? { "x-share-pin": nextPin } : {},
    })
      .then((body) => {
        const card = body as Preview;
        setPreview(card);
        setState(card.pinRequired ? "pin" : "ready");
      })
      .catch((cause: unknown) => {
        if (cause instanceof ApiError && cause.status === 410) {
          setState("gone");
          return;
        }
        if (cause instanceof ApiError && cause.status === 401) {
          setError(cause.problem.title);
          setState("pin");
          return;
        }
        if (cause instanceof ApiError && cause.status === 404) {
          setState("gone");
          return;
        }
        setState("network");
      })
      .finally(() => setPending(false));
  }

  useEffect(() => {
    load();
  }, [token]);

  if (state === "loading") return <LoadingState label="Opening this share…" />;
  if (state === "network") return <NetworkState onRetry={() => load(pin || undefined)} />;
  if (state === "gone") {
    return (
      <section className="panel">
        <h1>This link is no longer available</h1>
        <p>It may have expired, been revoked, or already been saved.</p>
      </section>
    );
  }

  const next = `/s/${token}`;

  return (
    <section className="panel">
      <h1>{preview?.title ?? "Shared card"}</h1>
      <p>{preview?.senderName ?? "Someone"} shared these fields with you.</p>
      {error ? <ValidationState message={error} /> : null}
      {state === "pin" ? (
        <form
          onSubmit={(event) => {
            event.preventDefault();
            load(pin);
          }}
        >
          <label>
            PIN
            <input
              value={pin}
              inputMode="numeric"
              autoComplete="off"
              onChange={(event) => setPin(event.target.value)}
            />
          </label>
          <button type="submit" disabled={pending || pin.length < 4}>
            Show card
          </button>
        </form>
      ) : (
        <>
          <ul>
            {(preview?.contacts ?? []).map((contact) => (
              <li key={`${contact.kind}-${contact.value}`}>
                {contact.href ? <a href={contact.href}>{contact.value}</a> : contact.value}
              </li>
            ))}
            {(preview?.addresses ?? []).map((address) => (
              <li key={address}>{address}</li>
            ))}
            {(preview?.socials ?? []).map((social) => (
              <li key={social.url}>
                <a href={social.url}>{social.platform}</a>
              </li>
            ))}
          </ul>
          <div className="row">
            <button
              type="button"
              className="secondary"
              onClick={() => {
                void fetch(`/api/v1/public/shares/${encodeURIComponent(token)}/vcard`, {
                  headers: pin ? { "x-share-pin": pin } : {},
                }).then(async (response) => {
                  if (!response.ok) {
                    setError("The vCard could not be saved.");
                    return;
                  }
                  const blob = await response.blob();
                  const url = URL.createObjectURL(blob);
                  const link = document.createElement("a");
                  link.href = url;
                  link.download = "card.vcf";
                  link.click();
                  URL.revokeObjectURL(url);
                });
              }}
            >
              Save vCard
            </button>
          </div>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              if (!auth.accessToken) {
                router.push(`/login?next=${encodeURIComponent(next)}`);
                return;
              }
              setPending(true);
              setError(null);
              void apiSend(`/v1/public/shares/${encodeURIComponent(token)}/claim`, {
                method: "POST",
                token: auth.accessToken,
                body: JSON.stringify({ consent: true, ...(pin ? { pin } : {}) }),
              })
                .then((body) => {
                  const saved = body as { walletEntryId?: string };
                  if (saved.walletEntryId) router.push(`/wallet/${saved.walletEntryId}`);
                })
                .catch((cause: unknown) => {
                  setError(
                    cause instanceof ApiError
                      ? cause.problem.title
                      : "We couldn't reach Softxu. Check your connection and try again.",
                  );
                })
                .finally(() => setPending(false));
            }}
          >
            <label className="choice">
              <input
                type="checkbox"
                checked={consent}
                onChange={(event) => setConsent(event.target.checked)}
              />
              <span>
                Save a copy of these fields in my wallet. This does not change the sender's card.
              </span>
            </label>
            {auth.status === "ready" ? (
              <button type="submit" disabled={pending || !consent}>
                {pending ? "Saving…" : "Add to wallet"}
              </button>
            ) : (
              <p>
                <Link href={`/login?next=${encodeURIComponent(next)}`}>Sign in</Link> to add this
                card to a wallet.
              </p>
            )}
          </form>
        </>
      )}
    </section>
  );
}
