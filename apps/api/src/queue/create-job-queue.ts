import type { AppEnv } from "../config/env";
import type { JobQueue } from "./job-queue";
import { MockJobQueue } from "./mock-job-queue";
import { SqsJobQueue } from "./sqs-job-queue";

export function createJobQueue(env: AppEnv): JobQueue {
  if (env.queueMode === "mock") return new MockJobQueue();
  return new SqsJobQueue(env);
}
