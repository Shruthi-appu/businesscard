import { beforeEach, describe, expect, it } from "vitest";

import { readWalletCache, writeWalletCache } from "./wallet-cache";

describe("wallet cache", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("round-trips the last unfiltered wallet", () => {
    writeWalletCache({
      userId: "00000000-0000-4000-8000-000000000001",
      displayName: "Ada Lovelace",
      cards: [
        {
          id: "card-1",
          title: "Analytical Engine",
          headline: "Ada Lovelace",
          company: "Engines",
          isFavourite: false,
        },
      ],
    });
    expect(readWalletCache()?.cards[0]?.title).toBe("Analytical Engine");
  });

  it("returns null when the stored value is not a wallet", () => {
    window.localStorage.setItem("softxu-wallet-cache", "{");
    expect(readWalletCache()).toBeNull();
  });
});
