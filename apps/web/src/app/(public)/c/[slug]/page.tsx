import { notFound } from "next/navigation";

type PublicContact = { kind: string; value: string; href: string | null };
type PublicCard = {
  title: string;
  layout: string;
  color: string;
  typeScale: "sm" | "md" | "lg";
  frontHeadline: string;
  frontSubline: string;
  backNote: string;
  contacts: PublicContact[];
  addresses: string[];
  socials: Array<{ platform: string; url: string }>;
};

export default async function PublicCardPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const origin = process.env.API_PROXY_ORIGIN ?? "http://127.0.0.1:3001";
  const response = await fetch(`${origin}/v1/public/cards/${encodeURIComponent(slug)}`, {
    cache: "no-store",
  });
  if (response.status === 404) notFound();
  if (!response.ok) {
    return (
      <section className="panel">
        <h1>Card unavailable</h1>
        <p>We couldn't load this card. Try the link again in a moment.</p>
      </section>
    );
  }
  const card = (await response.json()) as PublicCard;
  const color = /^#[0-9a-f]{6}$/i.test(card.color) ? card.color : "#0f6e56";
  return (
    <article
      className={`public-card ${card.layout === "split" ? "split" : ""}`}
      data-scale={card.typeScale}
      style={{ background: color }}
    >
      <div>
        <h1>{card.frontHeadline || card.title}</h1>
        {card.frontSubline ? <p>{card.frontSubline}</p> : null}
        <ul>
          {card.contacts.map((contact) => (
            <li key={`${contact.kind}-${contact.value}`}>
              {contact.href ? <a href={contact.href}>{contact.value}</a> : contact.value}
            </li>
          ))}
          {card.addresses.map((address) => (
            <li key={address}>{address}</li>
          ))}
          {card.socials.map((social) => (
            <li key={social.url}>
              <a href={social.url}>{social.platform}</a>
            </li>
          ))}
        </ul>
      </div>
      {card.backNote ? <p>{card.backNote}</p> : null}
    </article>
  );
}
