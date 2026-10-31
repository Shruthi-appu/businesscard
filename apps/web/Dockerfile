FROM node:22-bookworm-slim AS build
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.33.4 --activate
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json apps/web/package.json
COPY packages/contracts/package.json packages/contracts/package.json
RUN pnpm install --frozen-lockfile --filter @softxu/web...
COPY packages/contracts packages/contracts
COPY apps/web/next.config.ts apps/web/tsconfig.json apps/web/next-env.d.ts apps/web/
COPY apps/web/src apps/web/src
ARG API_PROXY_ORIGIN=http://localhost:3001
ENV API_PROXY_ORIGIN=$API_PROXY_ORIGIN
RUN pnpm --filter @softxu/contracts build && pnpm --filter @softxu/web build

FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
COPY --from=build /app/apps/web/.next/standalone ./
COPY --from=build /app/apps/web/.next/static ./apps/web/.next/static
EXPOSE 3000
CMD ["node", "apps/web/server.js"]
