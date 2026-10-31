import type { WalletCard } from "@/components/wallet-view";

const CACHE_KEY = "softxu-wallet-cache";

export type CachedWallet = {
  userId: string;
  displayName: string;
  cards: WalletCard[];
};

export function readWalletCache(): CachedWallet | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<CachedWallet>;
    if (!parsed || typeof parsed.userId !== "string" || !Array.isArray(parsed.cards)) return null;
    return {
      userId: parsed.userId,
      displayName: typeof parsed.displayName === "string" ? parsed.displayName : "Member",
      cards: parsed.cards,
    };
  } catch {
    return null;
  }
}

export function writeWalletCache(value: CachedWallet): void {
  window.localStorage.setItem(CACHE_KEY, JSON.stringify(value));
}
