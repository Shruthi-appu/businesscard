import { DeniedState, LoadingState, NetworkState } from "./states";

export function WalletView({
  state,
  displayName,
  onRetry,
  onSignOut,
  signOutError,
}: {
  state: "loading" | "empty" | "denied" | "network";
  displayName?: string;
  onRetry?: () => void;
  onSignOut?: () => void;
  signOutError?: string | null;
}) {
  if (state === "loading") return <LoadingState label="Loading your wallet…" />;
  if (state === "network") return <NetworkState onRetry={onRetry} />;
  if (state === "denied") return <DeniedState message="You do not have access to this wallet." />;
  return (
    <section className="empty">
      <p role="status">Signed in as {displayName}</p>
      <div className="card-outline" aria-hidden="true" />
      <h1>No cards yet</h1>
      <p>Cards you create or receive will show up here.</p>
      {signOutError ? <DeniedState message={signOutError} /> : null}
      {onSignOut ? (
        <button type="button" className="secondary" onClick={onSignOut}>
          Sign out
        </button>
      ) : null}
    </section>
  );
}
