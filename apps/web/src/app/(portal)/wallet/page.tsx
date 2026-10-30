"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { WalletView } from "@/components/wallet-view";
import { ApiError, loadCards, loadMe, logoutSession } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type View = "loading" | "empty" | "denied" | "network";

export default function WalletPage() {
  const auth = useAuth();
  const router = useRouter();
  const [view, setView] = useState<View>("loading");
  const [displayName, setDisplayName] = useState<string | undefined>(auth.user?.displayName);
  const [signOutError, setSignOutError] = useState<string | null>(null);
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
    setView("loading");
    Promise.all([loadMe(auth.accessToken), loadCards(auth.accessToken)])
      .then(([me, cards]) => {
        if (cancelled) return;
        setDisplayName(me.displayName);
        setView(cards.items.length === 0 ? "empty" : "empty");
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        if (error instanceof ApiError && error.status === 403) {
          setView("denied");
          return;
        }
        if (error instanceof ApiError && error.status === 401) {
          auth.clearSession();
          return;
        }
        setView("network");
      });
    return () => {
      cancelled = true;
    };
  }, [auth, reloadKey]);

  if (auth.status === "loading" || auth.status === "anonymous") {
    return <WalletView state="loading" />;
  }

  return (
    <section className="panel">
      <WalletView
        state={view}
        displayName={displayName}
        signOutError={signOutError}
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
    </section>
  );
}
