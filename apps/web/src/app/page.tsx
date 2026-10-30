import Link from "next/link";

export default function HomePage() {
  return (
    <section className="hero">
      <div>
        <h1>A quieter place for the cards you keep.</h1>
        <p className="lede">
          Softxu is a wallet for business cards. This first step is an account and an empty wallet.
          Scanning, sharing, and exchange come later.
        </p>
        <div className="actions">
          <Link className="button" href="/register">
            Create an account
          </Link>
          <Link className="button secondary" href="/login">
            Sign in
          </Link>
        </div>
      </div>
      <aside className="panel">
        <h2>Nothing stored yet</h2>
        <p>After you sign in, the wallet is empty until a later phase can add cards.</p>
      </aside>
    </section>
  );
}
