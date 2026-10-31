import { createApp } from "./app.factory";
import { AccountService } from "./modules/me/account.service";

async function main(): Promise<void> {
  const app = await createApp();
  try {
    const purged = await app.get(AccountService).purgeDue();
    process.stdout.write(`${JSON.stringify({ purged })}\n`);
  } finally {
    await app.close();
  }
}

void main();
