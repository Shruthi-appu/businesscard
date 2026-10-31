import Link from "next/link";

import { DeniedState, LoadingState, NetworkState } from "./states";

export type WalletCard = {
  id: string;
  title: string;
  headline: string | null;
  company: string | null;
  isFavourite: boolean;
};

export function WalletView({
  state,
  displayName,
  cards = [],
  query = "",
  filter = "all",
  onQuery,
  onFilter,
  onRetry,
  onSignOut,
  signOutError,
}: {
  state: "loading" | "empty" | "ready" | "denied" | "network";
  displayName?: string;
  cards?: WalletCard[];
  query?: string;
  filter?: string;
  onQuery?: (value: string) => void;
  onFilter?: (value: string) => void;
  onRetry?: () => void;
  onSignOut?: () => void;
  signOutError?: string | null;
}) {
  if (state === "loading") return <LoadingState label="Loading your wallet…" />;
  if (state === "network") return <NetworkState onRetry={onRetry} />;
  if (state === "denied") return <DeniedState message="You do not have access to this wallet." />;
  return (
    <section>
      <p role="status">Signed in as {displayName}</p>
      <div className="row">
        <Link className="button" href="/wallet/new">
          Add a card
        </Link>
        <Link className="button secondary" href="/wallet/scan">
          Scan a card
        </Link>
        {onSignOut ? (
          <button type="button" className="secondary" onClick={onSignOut}>
            Sign out
          </button>
        ) : null}
      </div>
      {onQuery ? (
        <form
          onSubmit={(event) => {
            event.preventDefault();
          }}
        >
          <label>
            Search
            <input
              name="q"
              value={query}
              onChange={(event) => onQuery(event.target.value)}
              placeholder="Name, company, email, tag"
            />
          </label>
          {onFilter ? (
            <label>
              Show
              <select
                name="filter"
                value={filter}
                onChange={(event) => onFilter(event.target.value)}
              >
                <option value="all">All cards</option>
                <option value="favourites">Favourites</option>
                <option value="manual">Typed in</option>
              </select>
            </label>
          ) : null}
        </form>
      ) : null}
      {cards.length === 0 ? (
        <div className="empty">
          <div className="card-outline" aria-hidden="true" />
          <h1>{query || filter !== "all" ? "No matching cards" : "No cards yet"}</h1>
          <p>
            {query || filter !== "all"
              ? "Try a different search or show all cards."
              : "Cards you create or receive will show up here."}
          </p>
        </div>
      ) : (
        <ul className="wallet-list">
          {cards.map((card) => (
            <li key={card.id}>
              <Link href={`/wallet/${card.id}`}>
                <strong>{card.headline ?? card.title}</strong>
                <span>{card.company ?? card.title}</span>
                {card.isFavourite ? <span>Favourite</span> : null}
              </Link>
            </li>
          ))}
        </ul>
      )}
      {signOutError ? <DeniedState message={signOutError} /> : null}
    </section>
  );
}
