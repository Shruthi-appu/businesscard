import {
  BLE_NFC_UNAVAILABLE,
  exchangeUrl,
  hashExchangeCode,
} from "../../src/modules/exchange/exchange-link";

describe("exchange link", () => {
  it("puts only the session URL in the QR target", () => {
    const phone = "+14155550197";
    const code = "abcDEF123_-exchange";
    const url = exchangeUrl("http://localhost:3000/", "11111111-1111-4111-8111-111111111111", code);
    expect(url).toBe(
      "http://localhost:3000/exchange/11111111-1111-4111-8111-111111111111?c=abcDEF123_-exchange",
    );
    expect(url).not.toContain(phone);
    expect(hashExchangeCode(code)).toHaveLength(64);
    expect(hashExchangeCode(code)).not.toBe(code);
    expect(BLE_NFC_UNAVAILABLE).toContain("Use QR");
  });
});
