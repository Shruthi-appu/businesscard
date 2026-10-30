import { PipeTransform } from "@nestjs/common";
import type { ZodError, ZodType } from "zod";

import { ApiException, type FieldError } from "./api.exception";

export function zodFieldErrors(error: ZodError): FieldError[] {
  return error.issues.map((issue) => ({
    field: issue.path.join(".") || "body",
    message: issue.message,
  }));
}

export class ZodValidationPipe<T> implements PipeTransform {
  constructor(private readonly schema: ZodType<T>) {}

  transform(value: unknown): T {
    const parsed = this.schema.safeParse(value ?? {});
    if (!parsed.success) {
      throw new ApiException(
        400,
        "validation_error",
        "Validation failed",
        zodFieldErrors(parsed.error),
      );
    }
    return parsed.data;
  }
}
