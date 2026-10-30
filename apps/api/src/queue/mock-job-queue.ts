import { randomUUID } from "crypto";

import type { JobQueue, QueueName } from "./job-queue";

export class MockJobQueue implements JobQueue {
  readonly kind = "mock" as const;
  readonly messages: { queue: QueueName; body: unknown; messageId: string }[] = [];

  async health(): Promise<void> {
    return;
  }

  async send(queue: QueueName, body: unknown): Promise<{ messageId: string }> {
    const messageId = randomUUID();
    this.messages.push({ queue, body, messageId });
    return { messageId };
  }
}
