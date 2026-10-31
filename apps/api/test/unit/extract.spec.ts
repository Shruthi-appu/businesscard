import { extractGrounded } from "../../src/modules/scans/extract";

describe("grounded extractor", () => {
  it("drops a value that is not in the raw text", () => {
    const draft = extractGrounded("Ada Lovelace\nAnalytical Engines");
    expect(draft.find((row) => row.kind === "email")?.value).toBeNull();
    expect(draft.find((row) => row.kind === "name")?.value).toBe("Ada Lovelace");
    expect(draft.find((row) => row.kind === "company")?.value).toBe("Analytical Engines");
  });
});
