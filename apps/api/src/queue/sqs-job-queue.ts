import { GetQueueAttributesCommand, SendMessageCommand, SQSClient } from "@aws-sdk/client-sqs";

import type { AppEnv } from "../config/env";
import type { JobQueue, QueueName } from "./job-queue";

export class SqsJobQueue implements JobQueue {
  readonly kind = "sqs" as const;
  private readonly client: SQSClient;
  private readonly urls: Record<QueueName, string>;

  constructor(env: AppEnv) {
    this.urls = {
      "image-processing": env.SQS_IMAGE_QUEUE_URL,
      "ocr-extraction": env.SQS_OCR_QUEUE_URL,
      export: env.SQS_EXPORT_QUEUE_URL,
    };
    this.client = new SQSClient({
      region: env.SQS_REGION,
      endpoint: env.SQS_ENDPOINT,
      credentials: {
        accessKeyId: env.SQS_ACCESS_KEY_ID.trim() || "local",
        secretAccessKey: env.SQS_SECRET_ACCESS_KEY.trim() || "local",
      },
    });
  }

  async health(): Promise<void> {
    await this.client.send(
      new GetQueueAttributesCommand({
        QueueUrl: this.urls["image-processing"],
        AttributeNames: ["QueueArn"],
      }),
    );
  }

  async send(queue: QueueName, body: unknown): Promise<{ messageId: string }> {
    const result = await this.client.send(
      new SendMessageCommand({
        QueueUrl: this.urls[queue],
        MessageBody: JSON.stringify(body),
      }),
    );
    return { messageId: result.MessageId ?? "unknown" };
  }
}
