export type QueueName = "image-processing" | "ocr-extraction" | "export";

export interface JobQueue {
  readonly kind: "mock" | "sqs";
  health(): Promise<void>;
  send(queue: QueueName, body: unknown): Promise<{ messageId: string }>;
}

export const JOB_QUEUE = Symbol("JOB_QUEUE");
