"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { LoadingState, NetworkState, ValidationState } from "@/components/states";
import { ApiError, apiSend } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type Template = {
  key: string;
  name: string;
  version: number;
  allowedColors: string[];
  allowedTypeScales: Array<"sm" | "md" | "lg">;
};

export default function CreateDigitalCardPage() {
  const auth = useAuth();
  const router = useRouter();
  const [templates, setTemplates] = useState<Template[]>([]);
  const [templateKey, setTemplateKey] = useState("classic");
  const [color, setColor] = useState("#0f6e56");
  const [typeScale, setTypeScale] = useState<"sm" | "md" | "lg">("md");
  const [phonePublic, setPhonePublic] = useState(false);
  const [pending, setPending] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [preview, setPreview] = useState({
    name: "",
    email: "",
    phone: "",
    headline: "",
    back: "",
  });

  useEffect(() => {
    if (auth.status === "anonymous") router.replace("/login");
  }, [auth.status, router]);

  useEffect(() => {
    void apiSend("/v1/templates")
      .then((body) => {
        const items = (body as { items: Template[] }).items ?? [];
        setTemplates(items);
        const first = items[0];
        if (first) {
          setTemplateKey(first.key);
          setColor(first.allowedColors[0] ?? "#0f6e56");
        }
      })
      .catch(() => setFormError("We couldn't load the templates."));
  }, []);

  const selected = templates.find((item) => item.key === templateKey) ?? templates[0];

  if (auth.status === "loading" || auth.status === "anonymous") {
    return <LoadingState label="Checking your session…" />;
  }
  if (auth.status === "network") {
    return <NetworkState onRetry={auth.retry} />;
  }

  return (
    <section className="narrow panel">
      <p>
        <Link href="/wallet">Back to wallet</Link>
      </p>
      <h1>Design a card</h1>
      <p>Pick a template, then choose what strangers can see.</p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (!auth.accessToken) return;
          const data = new FormData(event.currentTarget);
          const title = String(data.get("title") ?? "");
          const name = String(data.get("name") ?? "");
          const email = String(data.get("email") ?? "");
          const phone = String(data.get("phone") ?? "");
          const slug = String(data.get("slug") ?? "")
            .trim()
            .toLowerCase();
          const headline = String(data.get("headline") ?? name);
          const subline = String(data.get("subline") ?? "");
          const backNote = String(data.get("back") ?? "");
          const contacts = [
            name ? { kind: "name", value: name, isPrimary: true, isPublic: true } : null,
            email ? { kind: "email", value: email, isPublic: true } : null,
            phone ? { kind: "phone", value: phone, isPublic: phonePublic } : null,
          ].filter((row) => row !== null);
          setPending(true);
          setFormError(null);
          const token = auth.accessToken;
          void apiSend("/v1/digital-cards", {
            method: "POST",
            token,
            body: JSON.stringify({ title, templateKey, contacts }),
          })
            .then((created) => {
              const id = (created as { id: string }).id;
              return apiSend(`/v1/digital-cards/${id}/design`, {
                method: "PATCH",
                token,
                body: JSON.stringify({
                  color,
                  typeScale,
                  frontHeadline: headline,
                  frontSubline: subline,
                  backNote,
                }),
              }).then(() =>
                apiSend(`/v1/digital-cards/${id}/publish`, {
                  method: "POST",
                  token,
                  body: JSON.stringify({ slug, visibility: "public" }),
                }),
              );
            })
            .then(() => router.push(`/c/${slug}`))
            .catch((error: unknown) => {
              setFormError(
                error instanceof ApiError
                  ? error.problem.title
                  : "We couldn't reach Softxu. Check your connection and try again.",
              );
            })
            .finally(() => setPending(false));
        }}
      >
        {formError ? <ValidationState message={formError} /> : null}
        <label>
          Template
          <select
            name="template"
            value={templateKey}
            onChange={(event) => {
              const next = templates.find((item) => item.key === event.target.value);
              setTemplateKey(event.target.value);
              if (next) setColor(next.allowedColors[0] ?? color);
            }}
          >
            {templates.map((item) => (
              <option key={`${item.key}-${item.version}`} value={item.key}>
                {item.name} v{item.version}
              </option>
            ))}
          </select>
        </label>
        <label>
          Card title
          <input name="title" required />
        </label>
        <label>
          Name
          <input
            name="name"
            required
            onChange={(event) =>
              setPreview((current) => ({ ...current, name: event.target.value }))
            }
          />
        </label>
        <label>
          Public email
          <input
            name="email"
            type="email"
            onChange={(event) =>
              setPreview((current) => ({ ...current, email: event.target.value }))
            }
          />
        </label>
        <label>
          Phone
          <input
            name="phone"
            onChange={(event) =>
              setPreview((current) => ({ ...current, phone: event.target.value }))
            }
          />
        </label>
        <label>
          <span>Show the phone on the public card</span>
          <input
            type="checkbox"
            checked={phonePublic}
            onChange={(event) => setPhonePublic(event.target.checked)}
          />
        </label>
        <label>
          Colour
          <select name="color" value={color} onChange={(event) => setColor(event.target.value)}>
            {(selected?.allowedColors ?? [color]).map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </label>
        <label>
          Type scale
          <select
            name="typeScale"
            value={typeScale}
            onChange={(event) => setTypeScale(event.target.value as "sm" | "md" | "lg")}
          >
            {(selected?.allowedTypeScales ?? ["sm", "md", "lg"]).map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </label>
        <label>
          Front line
          <input
            name="headline"
            onChange={(event) =>
              setPreview((current) => ({ ...current, headline: event.target.value }))
            }
          />
        </label>
        <label>
          Front detail
          <input name="subline" />
        </label>
        <label>
          Back note
          <input
            name="back"
            onChange={(event) =>
              setPreview((current) => ({ ...current, back: event.target.value }))
            }
          />
        </label>
        <label>
          Public link
          <input
            name="slug"
            required
            placeholder="ada-lovelace"
            pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
          />
        </label>
        <div className="preview" style={{ background: color, color: "#f7fffb" }}>
          <strong>{preview.headline || preview.name || "Your name"}</strong>
          {preview.email ? <p>{preview.email}</p> : null}
          {phonePublic && preview.phone ? <p>{preview.phone}</p> : null}
          {preview.back ? <p>{preview.back}</p> : null}
        </div>
        <button type="submit" disabled={pending || templates.length === 0}>
          {pending ? "Publishing…" : "Publish card"}
        </button>
      </form>
    </section>
  );
}
