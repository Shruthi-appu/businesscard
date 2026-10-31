import { inflateRawSync, inflateSync } from "node:zlib";

import {
  buildPublicCard,
  qrPayload,
  renderExport,
  toVcard,
  type DesignConfig,
} from "../../src/modules/digital-cards/render";

const design: DesignConfig = {
  templateKey: "classic",
  templateVersion: 1,
  color: "#0f6e56",
  typeScale: "md",
  logoAssetId: null,
  photoAssetId: null,
  frontHeadline: "Ada Lovelace",
  frontSubline: "Engineer",
  backNote: "Ask about engines",
};

describe("public card export", () => {
  const card = buildPublicCard({
    slug: "ada-lovelace",
    title: "Ada",
    layout: "classic",
    design,
    origin: "http://localhost:3000",
    contacts: [
      { kind: "name", value: "Ada Lovelace", valueNormalized: null, isPublic: true },
      {
        kind: "email",
        value: "ada@analytical.example",
        valueNormalized: "ada@analytical.example",
        isPublic: true,
      },
      { kind: "phone", value: "+14155550199", valueNormalized: "+14155550199", isPublic: false },
    ],
    addresses: [],
    socials: [],
  });

  it("keeps the QR payload to the public URL", () => {
    expect(qrPayload("http://localhost:3000/", "ada-lovelace")).toBe(
      "http://localhost:3000/c/ada-lovelace",
    );
    expect(card.publicUrl).toBe("http://localhost:3000/c/ada-lovelace");
    expect(JSON.stringify(card)).not.toContain("+14155550199");
  });

  it("omits a private phone from the vCard", () => {
    const vcard = toVcard(card);
    expect(vcard).toContain("EMAIL:ada@analytical.example");
    expect(vcard).not.toContain("+14155550199");
    expect(vcard).not.toContain("TEL:");
  });

  it("omits a private phone from the PDF", async () => {
    const pdf = await renderExport("pdf", card);
    const text = pdfPlaintext(pdf.body);
    expect(text).toContain("ada@analytical.example");
    expect(text).not.toContain("+14155550199");
  });
});

function pdfPlaintext(body: Buffer): string {
  const chunks = [body.toString("latin1")];
  const marker = Buffer.from("stream");
  const endMarker = Buffer.from("endstream");
  let offset = 0;
  while (offset < body.length) {
    const start = body.indexOf(marker, offset);
    if (start < 0) break;
    let dataStart = start + marker.length;
    if (body[dataStart] === 0x0d) dataStart += 1;
    if (body[dataStart] === 0x0a) dataStart += 1;
    const end = body.indexOf(endMarker, dataStart);
    if (end < 0) break;
    let dataEnd = end;
    if (dataEnd > dataStart && body[dataEnd - 1] === 0x0a) dataEnd -= 1;
    if (dataEnd > dataStart && body[dataEnd - 1] === 0x0d) dataEnd -= 1;
    const slice = body.subarray(dataStart, dataEnd);
    for (const inflate of [inflateSync, inflateRawSync]) {
      try {
        chunks.push(inflate(slice).toString("latin1"));
        break;
      } catch {
        // A neighbouring stream may use the other deflate wrapper.
      }
    }
    offset = end + endMarker.length;
  }
  return decodePdfHex(chunks.join("\n"));
}

function decodePdfHex(text: string): string {
  return text.replace(/<([0-9A-Fa-f\s]+)>/g, (literal, hex: string) => {
    const clean = hex.replace(/\s/g, "");
    if (clean.length < 2 || clean.length % 2 !== 0) return literal;
    return Buffer.from(clean, "hex").toString("latin1");
  });
}
