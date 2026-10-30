import { createParamDecorator, ExecutionContext } from "@nestjs/common";

import { ApiException } from "./api.exception";
import type { AccessPrincipal, RequestWithContext } from "./request-context";

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AccessPrincipal => {
    const request = ctx.switchToHttp().getRequest<RequestWithContext>();
    if (!request.user) {
      throw new ApiException(401, "unauthenticated", "Authentication required");
    }
    return request.user;
  },
);
