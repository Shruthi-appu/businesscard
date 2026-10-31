import { Inject, Injectable, Logger } from "@nestjs/common";

import { EnvService } from "../../config/env.service";

export function shareSmsLogLine(phoneE164: string, token: string): string {
  const digits = phoneE164.replace(/\D/g, "");
  const tail = digits.slice(-2);
  return `share sms mock phoneSuffix=${tail} tokenPrefix=${token.slice(0, 4)}`;
}

@Injectable()
export class MessageSender {
  private readonly logger = new Logger(MessageSender.name);

  constructor(@Inject(EnvService) private readonly env: EnvService) {}

  send(phoneE164: string, token: string): "mock" | "skipped" {
    const line = shareSmsLogLine(phoneE164, token);
    const configured =
      this.env.values.SMS_PROVIDER.trim() === "configured" &&
      this.env.values.SMS_API_KEY.trim().length > 0;
    if (configured) {
      this.logger.log(`share sms skipped ${line}`);
      return "skipped";
    }
    this.logger.log(line);
    return "mock";
  }
}
