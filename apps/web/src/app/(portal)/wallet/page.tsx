"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { AccountActions } from "@/components/account-actions";
import { WalletView, type WalletCard } from "@/components/wallet-view";
import { ApiError, loadCards, loadMe, logoutSession } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { readWalletCache, writeWalletCache } from "@/lib/wallet-cache";

type View = "loading" | "empty" | "ready" | "denied" | "network";

export default function WalletPage() {
  const auth = useAuth();
  const router = useRouter();
  const [view, setView] = useState<View>("loading");
  const [displayName, setDisplayName] = useState<string | undefined>(auth.user?.displayName);
  const [cards, setCards] = useState<WalletCard[]>([]);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [signOutError, setSignOutError] = useState<string | null>(null);
  const [offlineCopy, setOfflineCopy] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    if (auth.status === "anonymous") router.replace("/login");
  }, [auth.status, router]);

  useEffect(() => {
    if (auth.status === "network") {
      setView("network");
      return;
    }
    if (auth.status !== "ready" || !auth.accessToken) return;
    let cancelled = false;
    const token = auth.accessToken;
    const timer = window.setTimeout(
      () => {
        Promise.all([loadMe(token), loadCards(token, query, filter)])
          .then(([me, result]) => {
            if (cancelled) return;
            setOfflineCopy(null);
            setDisplayName(me.displayName);
            setCards(result.items);
            if (!query && filter === "all" && auth.user) {
              writeWalletCache({
                userId: auth.user.id,
                displayName: me.displayName,
                cards: result.items,
              });
            }
            setView(result.items.length === 0 ? "empty" : "ready");
          })
          .catch((error: unknown) => {
            if (cancelled) return;
            if (error instanceof ApiError && error.status === 403) {
              setOfflineCopy(null);
              setView("denied");
              return;
            }
            if (error instanceof ApiError && error.status === 401) {
              auth.clearSession();
              return;
            }
            const cached = readWalletCache();
            if (
              cached &&
              auth.user &&
              cached.userId === auth.user.id &&
              !query &&
              filter === "all"
            ) {
              setDisplayName(cached.displayName);
              setCards(cached.cards);
              setOfflineCopy("Showing cards saved on this device.");
              setView(cached.cards.length === 0 ? "empty" : "ready");
              return;
            }
            setOfflineCopy(null);
            setView("network");
          });
      },
      query ? 200 : 0,
    );
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [auth, reloadKey, query, filter]);

  if (auth.status === "loading" || auth.status === "anonymous") {
    return <WalletView state="loading" />;
  }

  return (
    <section className="panel">
      <WalletView
        state={view}
        displayName={displayName}
        cards={cards}
        query={query}
        filter={filter}
        onQuery={setQuery}
        onFilter={setFilter}
        signOutError={signOutError}
        offlineCopy={offlineCopy}
        onRetry={() => {
          if (auth.status === "network") auth.retry();
          setReloadKey((value) => value + 1);
        }}
        onSignOut={async () => {
          setSignOutError(null);
          try {
            await logoutSession(auth.accessToken);
            auth.clearSession();
            router.replace("/login");
          } catch (error) {
            setSignOutError(error instanceof ApiError ? error.problem.title : "Could not sign out");
          }
        }}
      />
      {auth.accessToken && (view === "ready" || view === "empty") ? (
        <AccountActions
          token={auth.accessToken}
          onDeleted={() => {
            auth.clearSession();
            router.replace("/login");
          }}
        />
      ) : null}
    </section>
  );
}
