import { DocumentBuilder } from "@nestjs/swagger";

export function swaggerConfig() {
  return new DocumentBuilder()
    .setTitle("Softxu API")
    .setDescription(
      "Phase 1 foundation. Register, sign in, refresh, log out, read the signed-in profile, and list an empty wallet. Cards, assets, scans, shares, and exchange respond with 501 until a later phase.",
    )
    .setVersion("0.1.0")
    .addServer("http://localhost:3001", "Local API")
    .addBearerAuth()
    .build();
}
