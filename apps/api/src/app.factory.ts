import { RequestMethod, type INestApplication } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { SwaggerModule } from "@nestjs/swagger";
import cookieParser from "cookie-parser";
import type { NextFunction, Request, Response } from "express";
import helmet from "helmet";

import { AppModule } from "./app.module";
import { ProblemFilter } from "./common/problem.filter";
import { requestContextMiddleware, type RequestWithContext } from "./common/request-context";
import { EnvService } from "./config/env.service";
import { swaggerConfig } from "./swagger";

export function configureApp(app: INestApplication): void {
  const env = app.get(EnvService);
  app.setGlobalPrefix("v1", {
    exclude: [{ path: "health", method: RequestMethod.GET }],
  });
  app.use(
    helmet({
      contentSecurityPolicy: env.values.swaggerEnabled ? false : undefined,
      hsts: env.values.NODE_ENV === "production",
      xContentTypeOptions: true,
    }),
  );
  app.use(cookieParser());
  app.use((req: Request, res: Response, next: NextFunction) => {
    requestContextMiddleware(req as RequestWithContext, res, next);
  });
  app.enableCors({
    origin: env.values.PUBLIC_WEB_ORIGIN,
    credentials: true,
    methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Authorization", "Content-Type", "Idempotency-Key", "X-Request-Id"],
  });
  app.useGlobalFilters(new ProblemFilter());
  if (env.values.swaggerEnabled) {
    const document = swaggerConfig();
    SwaggerModule.setup("docs", app, () => SwaggerModule.createDocument(app, document));
  }
  app.enableShutdownHooks();
}

export async function createApp(): Promise<INestApplication> {
  const app = await NestFactory.create(AppModule, {
    logger: process.env.NODE_ENV === "test" ? false : ["error", "warn", "log"],
  });
  configureApp(app);
  await app.init();
  return app;
}
