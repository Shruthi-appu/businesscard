"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { ValidationState } from "@/components/states";
import { ApiError, apiSend } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

type DraftContact = { kind: string; value: string | null };
type ScanView = {
  id: string;
  status: string;
  errorCode: string | null;
  draftVersion: number;
  retryAfterSeconds: number | null;
  draft: DraftContact[] | null;
};

async function fileBase64(
  file: File,
): Promise<{ bodyBase64: string; byteSize: number; checksumSha256: string }> {
  const bytes = new Uint8Array(await file.arrayBuffer());
  let binary = "";
  bytes.forEach((value) => {
    binary += String.fromCharCode(value);
  });
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  const checksumSha256 = [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  return { bodyBase64: btoa(binary), byteSize: bytes.byteLength, checksumSha256 };
}

export default function ScanPage() {
  const auth = useAuth();
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [scan, setScan] = useState<ScanView | null>(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [company, setCompany] = useState("");

  function applyDraft(body: ScanView) {
    setScan(body);
    const value = (kind: string) => body.draft?.find((row) => row.kind === kind)?.value ?? "";
    setName(value("name"));
    setEmail(value("email"));
    setPhone(value("phone"));
    setCompany(value("company"));
  }

  return (
    <section className="narrow panel">
      <p>
        <Link href="/wallet">Back to wallet</Link>
      </p>
      <h1>Scan a card</h1>
      <p>
        Add a photo of the front and the back. This build uses the mock reader, not a live OCR
        provider.
      </p>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (!auth.accessToken) return;
          const data = new FormData(event.currentTarget);
          const front = data.get("front");
          const back = data.get("back");
          if (
            !(front instanceof File) ||
            !(back instanceof File) ||
            front.size === 0 ||
            back.size === 0
          ) {
            setFormError("Choose a front and a back image.");
            return;
          }
          setPending(true);
          setFormError(null);
          const token = auth.accessToken;
          void (async () => {
            const created = (await apiSend("/v1/scans", {
              method: "POST",
              token,
              body: "{}",
            })) as ScanView;
            for (const [side, file] of [
              ["front", front],
              ["back", back],
            ] as const) {
              const payload = await fileBase64(file);
              const upload = (await apiSend(`/v1/scans/${created.id}/upload-url`, {
                method: "POST",
                token,
                body: JSON.stringify({
                  side,
                  mimeType: file.type === "image/png" ? "image/png" : "image/jpeg",
                  byteSize: payload.byteSize,
                  checksumSha256: payload.checksumSha256,
                }),
              })) as { assetId: string; method: string; uploadUrl: string };
              if (upload.method === "POST") {
                await apiSend(`/v1/scans/${created.id}/objects/${upload.assetId}`, {
                  method: "POST",
                  token,
                  body: JSON.stringify({ bodyBase64: payload.bodyBase64 }),
                });
              } else {
                const raw = await fetch(upload.uploadUrl, {
                  method: "PUT",
                  headers: { "content-type": file.type || "image/jpeg" },
                  body: file,
                });
                if (!raw.ok) throw new Error("upload failed");
              }
              const completed = (await apiSend(`/v1/scans/${created.id}/complete`, {
                method: "POST",
                token,
                body: JSON.stringify({ assetId: upload.assetId, side }),
              })) as ScanView;
              applyDraft(completed);
            }
          })()
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
          Front
          <input name="front" type="file" accept="image/jpeg,image/png" required />
        </label>
        <label>
          Back
          <input name="back" type="file" accept="image/jpeg,image/png" required />
        </label>
        <button type="submit" disabled={pending}>
          {pending ? "Reading…" : "Read card"}
        </button>
      </form>
      {scan?.status === "needs_review" ? (
        <form
          onSubmit={(event) => {
            event.preventDefault();
            if (!auth.accessToken || !scan) return;
            setPending(true);
            setFormError(null);
            const contacts = [
              name ? { kind: "name", value: name, isPrimary: true } : null,
              email ? { kind: "email", value: email } : null,
              phone ? { kind: "phone", value: phone } : null,
              company ? { kind: "company", value: company } : null,
            ].filter((row) => row !== null);
            void apiSend(`/v1/scans/${scan.id}/confirm`, {
              method: "POST",
              token: auth.accessToken,
              body: JSON.stringify({ version: scan.draftVersion, contacts }),
            })
              .then((body) => router.push(`/wallet/${(body as { cardId: string }).cardId}`))
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
          <h2>Check the fields</h2>
          <label>
            Name
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Email
            <input value={email} onChange={(event) => setEmail(event.target.value)} />
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
            {pending ? "Saving…" : "Save card"}
          </button>
        </form>
      ) : null}
      {scan?.status === "failed" ? (
        <p role="status">
          {scan.errorCode === "dlq"
            ? "This scan could not be read."
            : "Reading failed. Try the photos again."}
        </p>
      ) : null}
    </section>
  );
}
