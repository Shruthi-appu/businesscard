import { DocumentBuilder } from "@nestjs/swagger";

export function swaggerConfig() {
  return new DocumentBuilder()
    .setTitle("Softxu API")
    .setDescription(
      "Accounts, a manual wallet, mock scanning, and digital cards. Shares, exchange, and profile edits respond with 501 until a later phase.",
    )
    .setVersion("0.1.0")
    .addServer("http://localhost:3001", "Local API")
    .addBearerAuth()
    .build();
}
