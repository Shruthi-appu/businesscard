import { describe, expect, it } from "vitest";

import { safeReturnPath } from "./return-path";

describe("safeReturnPath", () => {
  it("allows a share link and an exchange URL", () => {
    expect(safeReturnPath("/s/abcdefghijklmnopqrstuvwxyz")).toBe("/s/abcdefghijklmnopqrstuvwxyz");
    expect(safeReturnPath("/exchange/11111111-1111-4111-8111-111111111111?c=abcDEF123_-code")).toBe(
      "/exchange/11111111-1111-4111-8111-111111111111?c=abcDEF123_-code",
    );
    expect(safeReturnPath("/wallet")).toBeNull();
    expect(safeReturnPath("https://example.com")).toBeNull();
    expect(
      safeReturnPath("/exchange/11111111-1111-4111-8111-111111111111?c=code&next=/admin"),
    ).toBeNull();
  });
});
