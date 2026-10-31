"use client";

import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";

import { DeniedState, LoadingState, NetworkState, ValidationState } from "@/components/states";
import { ApiError, apiSend } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type Preview = {
  title: string;
  contacts: Array<{ kind: string; label: string | null; value: string }>;
  addresses: Array<{ formattedAddress: string }>;
  socials: Array<{ platform: string; url: string }>;
};

type ExchangeView = {
  id: string;
  status: string;
  mode: "one_way" | "mutual";
  yourConsent: string;
  peer: { displayName: string; card: Preview | null } | null;
  receivedWalletEntryId: string | null;
};

type OwnedCard = { id: string; title: string; source: string };

export default function ExchangePage() {
  return (
    <Suspense fallback={<LoadingState label="Opening this exchange…" />}>
      <ExchangeJoin />
    </Suspense>
  );
}

function ExchangeJoin() {
  const params = useParams<{ id: string }>();
  const id = params.id.toLowerCase();
  const search = useSearchParams();
  const router = useRouter();
  const auth = useAuth();
  const codeFromLink = search.get("c") ?? "";
  const [pasted, setPasted] = useState("");
  const [view, setView] = useState<ExchangeView | null>(null);
  const [cards, setCards] = useState<OwnedCard[]>([]);
  const [cardId, setCardId] = useState("");
  const [state, setState] = useState<"loading" | "ready" | "need-code" | "denied" | "network">(
    "loading",
  );
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const joined = useRef(false);
  const completeKey = useRef(`exchange-complete-${id}`);

  const returnPath = codeFromLink ? `/exchange/${id}?c=${codeFromLink}` : `/exchange/${id}`;

  function fail(error: unknown) {
    if (error instanceof ApiError && error.network) {
      setState("network");
      return;
    }
    if (error instanceof ApiError && error.status === 404) {
      setState("denied");
      return;
    }
    if (error instanceof ApiError && error.status === 410) {
      setView({
        id,
        status: "expired",
        mode: "one_way",
        yourConsent: "pending",
        peer: null,
        receivedWalletEntryId: null,
      });
      setState("ready");
      return;
    }
    setError(error instanceof ApiError ? error.problem.title : "Could not open this exchange.");
    setState("ready");
  }

  function join(code: string) {
    if (!auth.accessToken || !code) {
      setState("need-code");
      return;
    }
    setPending(true);
    setError(null);
    void apiSend(`/v1/exchange-sessions/${id}/join`, {
      method: "POST",
      token: auth.accessToken,
      body: JSON.stringify({ code }),
    })
      .then((body) => {
        const next = body as ExchangeView;
        setView(next);
        setState("ready");
        if (next.mode === "mutual") return loadCards();
        return undefined;
      })
      .catch(fail)
      .finally(() => setPending(false));
  }

  function loadCards() {
    if (!auth.accessToken) return;
    void apiSend("/v1/cards", { token: auth.accessToken }).then((body) => {
      const list = body as { items?: OwnedCard[] };
      const owned = (list.items ?? []).filter((item) => !item.source.startsWith("received_"));
      setCards(owned);
      setCardId(owned[0]?.id ?? "");
    });
  }

  function consent(accept: boolean) {
    if (!auth.accessToken) return;
    setPending(true);
    setError(null);
    const body = accept
      ? { accept: true, ...(view?.mode === "mutual" && cardId ? { cardId } : {}) }
      : { accept: false };
    void apiSend(`/v1/exchange-sessions/${id}/consent`, {
      method: "POST",
      token: auth.accessToken,
      body: JSON.stringify(body),
    })
      .then((result) => {
        const next = result as ExchangeView;
        setView(next);
        if (!accept || next.status === "declined") return null;
        return apiSend(`/v1/exchange-sessions/${id}/complete`, {
          method: "POST",
          token: auth.accessToken,
          headers: { "Idempotency-Key": completeKey.current },
        });
      })
      .then((result) => {
        if (!result) return;
        const done = result as { receivedWalletEntryId?: string | null; status?: string };
        setView((current) =>
          current
            ? {
                ...current,
                status: "accepted",
                receivedWalletEntryId: done.receivedWalletEntryId ?? null,
                peer: null,
              }
            : current,
        );
      })
      .catch(fail)
      .finally(() => setPending(false));
  }

  useEffect(() => {
    if (auth.status === "loading") return;
    if (auth.status === "anonymous") {
      router.replace(`/login?next=${encodeURIComponent(returnPath)}`);
      return;
    }
    if (auth.status !== "ready" || !auth.accessToken || joined.current) return;
    joined.current = true;
    if (!codeFromLink) {
      setState("need-code");
      return;
    }
    join(codeFromLink);
  }, [auth.status, auth.accessToken, id]);

  if (auth.status === "loading" || state === "loading") {
    return <LoadingState label="Opening this exchange…" />;
  }
  if (state === "network") {
    return <NetworkState onRetry={() => join(codeFromLink || pasted)} />;
  }
  if (state === "denied") return <DeniedState message="This exchange was not found." />;
  if (state === "need-code") {
    return (
      <section className="panel">
        <h1>Join an exchange</h1>
        <p>Paste the code from the QR link. The code is not the contact card.</p>
        {error ? <ValidationState message={error} /> : null}
        <form
          onSubmit={(event) => {
            event.preventDefault();
            join(pasted.trim());
          }}
        >
          <label>
            Code
            <input value={pasted} onChange={(event) => setPasted(event.target.value)} />
          </label>
          <button type="submit" disabled={pending || pasted.trim().length < 8}>
            Continue
          </button>
        </form>
      </section>
    );
  }

  const preview = view?.peer?.card;
  return (
    <section className="panel">
      <h1>{preview?.title ?? "Exchange"}</h1>
      {view?.status === "expired" ? <p>This exchange expired. Nothing was saved.</p> : null}
      {view?.status === "declined" ? <p>This exchange was declined. Nothing was saved.</p> : null}
      {view?.status === "accepted" ? (
        <p role="status">
          Saved.{" "}
          {view.receivedWalletEntryId ? (
            <Link href={`/wallet/${view.receivedWalletEntryId}`}>Open the card</Link>
          ) : (
            "Your wallet did not gain a copy."
          )}
        </p>
      ) : null}
      {error ? <ValidationState message={error} /> : null}
      {view &&
      view.status !== "accepted" &&
      view.status !== "declined" &&
      view.status !== "expired" ? (
        <>
          <p>{view.peer?.displayName ?? "Someone"} wants to exchange a card.</p>
          {preview ? (
            <ul>
              {preview.contacts.map((contact) => (
                <li key={`${contact.kind}-${contact.value}`}>
                  {contact.kind}: {contact.value}
                </li>
              ))}
              {preview.addresses.map((address) => (
                <li key={address.formattedAddress}>{address.formattedAddress}</li>
              ))}
              {preview.socials.map((social) => (
                <li key={social.url}>
                  {social.platform}: {social.url}
                </li>
              ))}
            </ul>
          ) : (
            <p>The other person has not chosen a card yet.</p>
          )}
          {view.mode === "mutual" ? (
            <label>
              Your card
              <select value={cardId} onChange={(event) => setCardId(event.target.value)}>
                {cards.length === 0 ? <option value="">Create a card first</option> : null}
                {cards.map((card) => (
                  <option key={card.id} value={card.id}>
                    {card.title}
                  </option>
                ))}
              </select>
            </label>
          ) : null}
          <div className="row">
            <button
              type="button"
              disabled={pending || (view.mode === "mutual" && !cardId)}
              onClick={() => consent(true)}
            >
              Accept
            </button>
            <button
              type="button"
              className="secondary"
              disabled={pending}
              onClick={() => consent(false)}
            >
              Decline
            </button>
          </div>
        </>
      ) : null}
    </section>
  );
}
