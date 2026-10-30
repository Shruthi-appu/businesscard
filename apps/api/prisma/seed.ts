import { PrismaClient } from "@prisma/client";

import { hashPassword } from "../src/modules/auth/password";

const prisma = new PrismaClient();

async function main(): Promise<void> {
  if (process.env.SEED_DEMO !== "true") {
    console.log("SEED_DEMO is not true; skipping seed");
    return;
  }
  const email = process.env.DEMO_USER_EMAIL?.trim().toLowerCase();
  const password = process.env.DEMO_USER_PASSWORD;
  const displayName = process.env.DEMO_USER_DISPLAY_NAME?.trim();
  if (!email || !password || !displayName) {
    throw new Error(
      "SEED_DEMO requires DEMO_USER_EMAIL, DEMO_USER_PASSWORD, and DEMO_USER_DISPLAY_NAME",
    );
  }
  const passwordHash = await hashPassword(password);
  await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      passwordHash,
      profile: { create: { displayName } },
    },
  });
  console.log("Demo user is ready");
}

main()
  .catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "seed failed";
    console.error(message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
