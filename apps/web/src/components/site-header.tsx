"use client";

import Link from "next/link";

import { useAuth } from "@/lib/auth-context";

export function SiteHeader() {
  const auth = useAuth();
  return (
    <header className="topbar">
      <Link className="brand" href={auth.status === "ready" ? "/wallet" : "/"}>
        Softxu
      </Link>
      <nav className="row">
        {auth.status === "ready" ? (
          <Link className="button" href="/wallet">
            Wallet
          </Link>
        ) : (
          <>
            <Link href="/login">Sign in</Link>
            <Link className="button" href="/register">
              Register
            </Link>
          </>
        )}
      </nav>
    </header>
  );
}
