"use client";

import { useEffect, useState } from "react";

import { DeniedState, LoadingState, NetworkState } from "@/components/states";
import { ApiError, loadJobCounts, type JobCounts } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

export default function AdminPage() {
  const auth = useAuth();
  const [counts, setCounts] = useState<JobCounts | null>(null);
  const [failed, setFailed] = useState(false);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    if (auth.status !== "ready" || auth.user?.role !== "admin" || !auth.accessToken) return;
    let cancelled = false;
    const token = auth.accessToken;
    loadJobCounts(token)
      .then((body) => {
        if (cancelled) return;
        setFailed(false);
        setCounts(body);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
          auth.clearSession();
          return;
        }
        setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, [auth, reload]);

  if (auth.status === "loading") return <LoadingState label="Checking access…" />;
  if (auth.status === "network") return <NetworkState onRetry={auth.retry} />;
  if (auth.status !== "ready" || auth.user?.role !== "admin") {
    return <DeniedState message="You do not have access to admin tools." />;
  }
  if (failed) return <NetworkState onRetry={() => setReload((value) => value + 1)} />;
  if (!counts) return <LoadingState label="Loading job counts…" />;

  return (
    <section className="panel">
      <h1>Admin</h1>
      <p>Job counts. No card contents are shown.</p>
      <ul>
        <li>Pending deletion: {counts.pendingDeletion}</li>
        {Object.entries(counts.ocr).map(([status, count]) => (
          <li key={`ocr-${status}`}>
            Scan jobs {status}: {count}
          </li>
        ))}
        {Object.entries(counts.exports).map(([status, count]) => (
          <li key={`export-${status}`}>
            Exports {status}: {count}
          </li>
        ))}
      </ul>
    </section>
  );
}
