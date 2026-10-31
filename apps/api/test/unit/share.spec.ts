import { redactSharePath } from "../../src/common/request-context";
import { shareSmsLogLine } from "../../src/modules/shares/message-sender";

describe("share privacy", () => {
  it("logs a phone suffix and a four-character token prefix", () => {
    const token = "abcdEFGHijklmnop";
    const line = shareSmsLogLine("+14155550198", token);
    expect(line).toBe("share sms mock phoneSuffix=98 tokenPrefix=abcd");
    expect(line).not.toContain("14155550198");
    expect(line).not.toContain("EFGH");
  });

  it("keeps share tokens in request logs to a four-character prefix", () => {
    const path = redactSharePath("/v1/public/shares/abcdEFGHijklmnop/vcard");
    expect(path).toBe("/v1/public/shares/abcd/vcard");
    expect(path).not.toContain("EFGH");
  });
});
