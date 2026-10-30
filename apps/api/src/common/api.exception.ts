import { HttpException } from "@nestjs/common";

export type FieldError = { field: string; message: string };

export class ApiException extends HttpException {
  constructor(status: number, code: string, title: string, errors?: FieldError[]) {
    super({ code, title, errors }, status);
  }
}

export function notImplemented(title: string): never {
  throw new ApiException(501, "not_implemented", title);
}
