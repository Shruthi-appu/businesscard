"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { ApiError, apiSend } from "@/lib/api";

import { NetworkState, ValidationState } from "./states";

type Started = {
  id: string;
  url: string;
  qrPngBase64: string;
  expiresAt: string;
  status: string;
  mode: string;
  peerConsent: string | null;
  receivedWalletEntryId: string | null;
};

function secondsLeft(expiresAt: string): number {
  return Math.max(0, Math.ceil((new Date(expiresAt).getTime() - Date.now()) / 1000));
}

function clock(total: number): string {
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

export function ExchangeStart({ token, cardId }: { token: string | null; cardId: string }) {
  const [mode, setMode] = useState<"one_way" | "mutual">("one_way");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [network, setNetwork] = useState(false);
  const [session, setSession] = useState<Started | null>(null);
  const [remaining, setRemaining] = useState(0);
  const createKey = useRef(`exchange-create-${cardId}`);
  const completeKey = useRef("");
  const completing = useRef(false);
  const finished = useRef(false);

  function fail(error: unknown) {
    if (error instanceof ApiError && error.network) {
      setNetwork(true);
      setError(null);
      return;
    }
    setNetwork(false);
    setError(error instanceof ApiError ? error.problem.title : "Could not start this exchange.");
  }

  function start() {
    if (!token) return;
    setPending(true);
    setError(null);
    setNetwork(false);
    void apiSend("/v1/exchange-sessions", {
      method: "POST",
      token,
      headers: { "Idempotency-Key": createKey.current },
      body: JSON.stringify({ cardId, mode, method: "qr" }),
    })
      .then((body) => {
        const created = body as Started;
        completeKey.current = `exchange-complete-${created.id}`;
        setSession({ ...created, peerConsent: null, receivedWalletEntryId: null });
        setRemaining(secondsLeft(created.expiresAt));
      })
      .catch(fail)
      .finally(() => setPending(false));
  }

  function refresh(current: Started) {
    if (!token) return;
    void apiSend(`/v1/exchange-sessions/${current.id}`, { token })
      .then((body) => {
        const next = body as Partial<Started>;
        setNetwork(false);
        setSession({
          ...current,
          status: next.status ?? current.status,
          expiresAt: next.expiresAt ?? current.expiresAt,
          peerConsent: next.peerConsent ?? null,
          receivedWalletEntryId: next.receivedWalletEntryId ?? null,
        });
      })
      .catch((error: unknown) => {
        if (error instanceof ApiError && error.network) setNetwork(true);
      });
  }

  function finish(current: Started) {
    if (!token || completing.current || finished.current) return;
    completing.current = true;
    setPending(true);
    void apiSend(`/v1/exchange-sessions/${current.id}/complete`, {
      method: "POST",
      token,
      headers: { "Idempotency-Key": completeKey.current },
    })
      .then((body) => {
        const done = body as { receivedWalletEntryId?: string | null };
        finished.current = true;
        setSession({
          ...current,
          status: "accepted",
          receivedWalletEntryId: done.receivedWalletEntryId ?? null,
        });
        setNetwork(false);
      })
      .catch(fail)
      .finally(() => {
        completing.current = false;
        setPending(false);
      });
  }

  function stop(current: Started) {
    if (!token) return;
    setPending(true);
    setError(null);
    void apiSend(`/v1/exchange-sessions/${current.id}/consent`, {
      method: "POST",
      token,
      body: JSON.stringify({ accept: false }),
    })
      .then(() => setSession({ ...current, status: "declined", peerConsent: null }))
      .catch(fail)
      .finally(() => setPending(false));
  }

  useEffect(() => {
    if (!session || session.status === "accepted" || session.status === "declined") return;
    const timer = window.setInterval(() => {
      const left = secondsLeft(session.expiresAt);
      setRemaining(left);
      if (left === 0) setSession({ ...session, status: "expired" });
    }, 1000);
    return () => window.clearInterval(timer);
  }, [session]);

  useEffect(() => {
    if (!session || (session.status !== "open" && session.status !== "joined")) return;
    const timer = window.setInterval(() => refresh(session), 2000);
    return () => window.clearInterval(timer);
  }, [session, token]);

  useEffect(() => {
    if (!session || session.status !== "joined" || session.peerConsent !== "accepted") return;
    finish(session);
  }, [session, token]);

  return (
    <form
      onSubmit={(event) => {
        event.preventDefault();
        start();
      }}
    >
      <h2>Exchange in person</h2>
      <p>
        This QR is a short-lived exchange. It is not the public card QR, and it does not contain the
        contact details.
      </p>
      {network ? (
        <NetworkState
          onRetry={() => {
            if (session?.peerConsent === "accepted" && session.status === "joined") finish(session);
            else if (session) refresh(session);
            else start();
          }}
        />
      ) : null}
      {error ? <ValidationState message={error} /> : null}
      {session ? (
        <div>
          <img
            className="qr"
            alt="Exchange QR code"
            src={`data:image/png;base64,${session.qrPngBase64}`}
          />
          <p>
            <input readOnly value={session.url} aria-label="Exchange link" />
          </p>
          {session.status === "open" || session.status === "joined" ? (
            <p role="status">
              Visible for {clock(remaining)}. Anyone who opens this link can ask to save the card.
            </p>
          ) : null}
          {session.status === "accepted" && session.mode === "one_way" ? (
            <p role="status">They saved your card. Your wallet did not gain a copy.</p>
          ) : null}
          {session.status === "accepted" &&
          session.mode === "mutual" &&
          session.receivedWalletEntryId ? (
            <p role="status">
              Exchange saved.{" "}
              <Link href={`/wallet/${session.receivedWalletEntryId}`}>Open the card</Link>
            </p>
          ) : null}
          {session.status === "declined" ? (
            <p role="status">This exchange was stopped. Nothing was saved.</p>
          ) : null}
          {session.status === "expired" ? (
            <p role="status">
              This exchange expired. Nothing was saved. Start again to show a new QR.
            </p>
          ) : null}
          {session.status === "open" || session.status === "joined" ? (
            <button
              type="button"
              className="secondary"
              disabled={pending}
              onClick={() => stop(session)}
            >
              Stop
            </button>
          ) : null}
        </div>
      ) : (
        <>
          <label>
            Exchange
            <select
              name="mode"
              value={mode}
              onChange={(event) => setMode(event.target.value === "mutual" ? "mutual" : "one_way")}
            >
              <option value="one_way">They save my card</option>
              <option value="mutual">We each save a card</option>
            </select>
          </label>
          <button type="submit" className="secondary" disabled={pending}>
            Show QR
          </button>
        </>
      )}
    </form>
  );
}
