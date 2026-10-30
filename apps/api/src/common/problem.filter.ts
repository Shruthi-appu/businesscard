import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import type { Response } from "express";

import { ApiException } from "./api.exception";
import type { RequestWithContext } from "./request-context";

function codeForStatus(status: number): string {
  switch (status) {
    case 400:
      return "validation_error";
    case 401:
      return "unauthenticated";
    case 403:
      return "forbidden";
    case 404:
      return "not_found";
    case 409:
      return "conflict";
    case 429:
      return "rate_limited";
    case 501:
      return "not_implemented";
    case 503:
      return "service_unavailable";
    default:
      return status >= 500 ? "internal_error" : "request_error";
  }
}

@Catch()
export class ProblemFilter implements ExceptionFilter {
  private readonly logger = new Logger(ProblemFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<RequestWithContext>();

    let status = 500;
    let code = "internal_error";
    let title = "Internal server error";
    let errors: { field: string; message: string }[] | undefined;

    if (exception instanceof ApiException) {
      status = exception.getStatus();
      const body = exception.getResponse() as {
        code: string;
        title: string;
        errors?: { field: string; message: string }[];
      };
      code = body.code;
      title = body.title;
      errors = body.errors;
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      code = codeForStatus(status);
      title =
        status === 404
          ? "Not found"
          : status === 401
            ? "Authentication required"
            : exception.message || title;
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      this.logger.error(
        `database_error code=${exception.code} requestId=${request.requestId ?? ""}`,
      );
    } else if (exception instanceof Error) {
      this.logger.error(
        `unhandled requestId=${request.requestId ?? ""} message=${exception.message}`,
      );
    } else {
      this.logger.error(`unhandled requestId=${request.requestId ?? ""}`);
    }

    response
      .status(status)
      .type("application/problem+json")
      .json({
        type: "about:blank",
        title,
        status,
        code,
        requestId: request.requestId ?? "unknown",
        ...(errors && errors.length > 0 ? { errors } : {}),
      });
  }
}
