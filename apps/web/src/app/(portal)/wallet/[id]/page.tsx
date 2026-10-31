"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";

import { DeniedState, LoadingState, NetworkState, ValidationState } from "@/components/states";
import { ApiError, apiSend } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type Contact = {
  kind: string;
  value: string;
  valueNormalized: string | null;
  whatsappState: string;
};
type Tag = { id: string; name: string };
type Detail = {
  id: string;
  walletEntryId: string;
  title: string;
  isFavourite: boolean;
  contacts: Contact[];
  addresses: Array<{ formattedAddress: string; isPublic: boolean }>;
  socials: Array<{ platform: string; url: string; isPublic: boolean }>;
  tags: Tag[];
  duplicateWarnings: Array<{ kind: string; valueNormalized: string }>;
};

function contactValue(contacts: Contact[], kind: string): string {
  return contacts.find((contact) => contact.kind === kind)?.value ?? "";
}

function draftContacts(name: string, email: string, phone: string, company: string) {
  return [
    name ? { kind: "name", value: name, isPrimary: true } : null,
    email ? { kind: "email", value: email } : null,
    phone ? { kind: "phone", value: phone } : null,
    company ? { kind: "company", value: company } : null,
  ].filter((row) => row !== null);
}

export default function CardDetailPage() {
  const auth = useAuth();
  const params = useParams<{ id: string }>();
  const [detail, setDetail] = useState<Detail | null>(null);
  const [state, setState] = useState<"loading" | "ready" | "denied" | "network">("loading");
  const [title, setTitle] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [company, setCompany] = useState("");
  const [tagName, setTagName] = useState("");
  const [pending, setPending] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  function apply(body: Detail) {
    setDetail({
      ...body,
      tags: body.tags ?? [],
      addresses: body.addresses ?? [],
      socials: body.socials ?? [],
    });
    setTitle(body.title);
    setName(contactValue(body.contacts, "name"));
    setEmail(contactValue(body.contacts, "email"));
    setPhone(contactValue(body.contacts, "phone"));
    setCompany(contactValue(body.contacts, "company"));
    setState("ready");
  }

  useEffect(() => {
    if (!auth.accessToken) return;
    let cancelled = false;
    apiSend(`/v1/cards/${params.id}`, { token: auth.accessToken })
      .then((body) => {
        if (!cancelled) apply(body as Detail);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        if (error instanceof ApiError && (error.status === 404 || error.status === 403)) {
          setState("denied");
          return;
        }
        setState("network");
      });
    return () => {
      cancelled = true;
    };
  }, [auth.accessToken, params.id]);

  if (state === "loading") return <LoadingState label="Loading this card…" />;
  if (state === "network") return <NetworkState />;
  if (state === "denied" || !detail)
    return <DeniedState message="You do not have access to this card." />;

  const phoneContact = detail.contacts.find((contact) => contact.kind === "phone");
  const emailContact = detail.contacts.find((contact) => contact.kind === "email");
  const website = detail.contacts.find((contact) => contact.kind === "website");

  return (
    <section className="panel">
      <p>
        <Link href="/wallet">Back to wallet</Link>
      </p>
      <h1>{detail.title}</h1>
      <div className="row">
        <button
          type="button"
          className="secondary"
          disabled={pending}
          onClick={() => {
            if (!auth.accessToken) return;
            setPending(true);
            setFormError(null);
            void apiSend(`/v1/wallet/entries/${detail.walletEntryId}/favourite`, {
              method: "POST",
              token: auth.accessToken,
              body: JSON.stringify({ isFavourite: !detail.isFavourite }),
            })
              .then((body) => {
                const next = body as { isFavourite: boolean };
                setDetail({ ...detail, isFavourite: next.isFavourite });
              })
              .catch((error: unknown) => {
                setFormError(
                  error instanceof ApiError ? error.problem.title : "Could not update this card.",
                );
              })
              .finally(() => setPending(false));
          }}
        >
          {detail.isFavourite ? "Remove favourite" : "Favourite"}
        </button>
        {phoneContact?.valueNormalized ? (
          <a href={`tel:${phoneContact.valueNormalized}`}>Call</a>
        ) : null}
        {emailContact ? <a href={`mailto:${emailContact.value}`}>Email</a> : null}
        {phoneContact?.whatsappState === "yes" && phoneContact.valueNormalized ? (
          <a href={`https://wa.me/${phoneContact.valueNormalized.replace("+", "")}`}>WhatsApp</a>
        ) : null}
        {website?.valueNormalized ? <a href={website.valueNormalized}>Website</a> : null}
      </div>
      {detail.duplicateWarnings.length > 0 ? (
        <p role="status">This email or phone is already in your wallet.</p>
      ) : null}
      {detail.tags.length > 0 ? (
        <ul className="row">
          {detail.tags.map((tag) => (
            <li key={tag.id}>{tag.name}</li>
          ))}
        </ul>
      ) : null}
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (!auth.accessToken || !tagName.trim()) return;
          setPending(true);
          setFormError(null);
          void apiSend(`/v1/wallet/entries/${detail.walletEntryId}/tags`, {
            method: "POST",
            token: auth.accessToken,
            body: JSON.stringify({ name: tagName.trim() }),
          })
            .then((body) => {
              const tag = body as Tag;
              setDetail({
                ...detail,
                tags: detail.tags.some((item) => item.id === tag.id)
                  ? detail.tags
                  : [...detail.tags, tag],
              });
              setTagName("");
            })
            .catch((error: unknown) => {
              setFormError(
                error instanceof ApiError ? error.problem.title : "Could not add that tag.",
              );
            })
            .finally(() => setPending(false));
        }}
      >
        <label>
          Tag
          <input
            value={tagName}
            onChange={(event) => setTagName(event.target.value)}
            placeholder="Met at conference"
          />
        </label>
        <button type="submit" className="secondary" disabled={pending || !tagName.trim()}>
          Add tag
        </button>
      </form>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (!auth.accessToken) return;
          setPending(true);
          setFormError(null);
          const edited = new Set(["name", "email", "phone", "company"]);
          const contacts = [
            ...draftContacts(name, email, phone, company),
            ...detail.contacts
              .filter((contact) => !edited.has(contact.kind))
              .map((contact) => ({ kind: contact.kind, value: contact.value })),
          ];
          void apiSend(`/v1/cards/${detail.id}`, {
            method: "PATCH",
            token: auth.accessToken,
            body: JSON.stringify({ title }),
          })
            .then(() =>
              apiSend(`/v1/cards/${detail.id}/versions`, {
                method: "POST",
                token: auth.accessToken,
                body: JSON.stringify({
                  contacts,
                  addresses: detail.addresses.map((address) => ({
                    formattedAddress: address.formattedAddress,
                    isPublic: address.isPublic,
                  })),
                  socials: detail.socials.map((social) => ({
                    platform: social.platform,
                    url: social.url,
                    isPublic: social.isPublic,
                  })),
                }),
              }),
            )
            .then((body) => apply(body as Detail))
            .catch((error: unknown) => {
              if (error instanceof ApiError && error.status === 400)
                setFormError(error.problem.title);
              else if (error instanceof ApiError) setFormError(error.problem.title);
              else setFormError("We couldn't reach Softxu. Check your connection and try again.");
            })
            .finally(() => setPending(false));
        }}
      >
        <h2>Edit card</h2>
        {formError ? <ValidationState message={formError} /> : null}
        <label>
          Card title
          <input value={title} required onChange={(event) => setTitle(event.target.value)} />
        </label>
        <label>
          Name
          <input value={name} required onChange={(event) => setName(event.target.value)} />
        </label>
        <label>
          Email
          <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label>
          Phone
          <input value={phone} onChange={(event) => setPhone(event.target.value)} />
        </label>
        <label>
          Company
          <input value={company} onChange={(event) => setCompany(event.target.value)} />
        </label>
        <button type="submit" disabled={pending}>
          {pending ? "Saving…" : "Save changes"}
        </button>
      </form>
    </section>
  );
}
