"use client";

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

import type { AuthUser } from "@softxu/contracts";

import { ApiError, refreshSession } from "./api";

export type AuthStatus = "loading" | "anonymous" | "ready" | "network";

type AuthState = {
  status: AuthStatus;
  accessToken: string | null;
  user: AuthUser | null;
  setSession: (accessToken: string, user: AuthUser) => void;
  clearSession: () => void;
  retry: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>("loading");
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setStatus("loading");
    refreshSession()
      .then((session) => {
        if (cancelled) return;
        if (!session) {
          setAccessToken(null);
          setUser(null);
          setStatus("anonymous");
          return;
        }
        setAccessToken(session.accessToken);
        setUser(session.user);
        setStatus("ready");
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        if (error instanceof ApiError && error.network) {
          setStatus("network");
          return;
        }
        setStatus("anonymous");
      });
    return () => {
      cancelled = true;
    };
  }, [attempt]);

  const value = useMemo<AuthState>(
    () => ({
      status,
      accessToken,
      user,
      setSession: (nextToken, nextUser) => {
        setAccessToken(nextToken);
        setUser(nextUser);
        setStatus("ready");
      },
      clearSession: () => {
        setAccessToken(null);
        setUser(null);
        setStatus("anonymous");
      },
      retry: () => setAttempt((value) => value + 1),
    }),
    [accessToken, status, user],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const value = useContext(AuthContext);
  if (!value) throw new Error("AuthProvider is missing");
  return value;
}
