"use client";

import { DeniedState, LoadingState, NetworkState } from "@/components/states";
import { useAuth } from "@/lib/auth-context";

export default function AdminPage() {
  const auth = useAuth();
  if (auth.status === "loading") return <LoadingState label="Checking access…" />;
  if (auth.status === "network") return <NetworkState onRetry={auth.retry} />;
  if (auth.status !== "ready" || auth.user?.role !== "admin") {
    return <DeniedState message="You do not have access to admin tools." />;
  }
  return (
    <section className="panel">
      <h1>Admin</h1>
      <p>Operational admin tools are not part of this phase.</p>
    </section>
  );
}
