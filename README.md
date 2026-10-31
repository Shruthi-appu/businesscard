# businesscard

Softxu is a business card wallet and networking platform for Softxu Technologies. This repository is the modular monolith described in the architecture plan: a NestJS API, a Next.js portal, a Flutter app, and a Python image worker. Phase 1 is accounts and an empty wallet. Phase 2 adds manual cards. Phase 3 adds a scan that uses a mock reader. Later phases are not in this tree.

## What works

A new person can register, sign in, and open a wallet on the web app and on the Flutter app. On the web they can add a card, edit it, search, mark a favourite, and tag it. The Flutter wallet lists card titles. The API checks the access token on every protected route, so one account cannot read another account's card or profile. Refresh tokens rotate and are stored only as an HMAC. Passwords are Argon2id hashes.

Local infrastructure is Docker Compose: Postgres 16, Redis 7, MinIO, and ElasticMQ. Nothing here provisions Fly or AWS, and there is no Terraform.

| Surface                                                   | Status                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------- |
| `POST /v1/auth/register`, `/login`, `/refresh`, `/logout` | Working                                                                   |
| `GET /v1/me`                                              | The caller only                                                           |
| `GET /v1/cards`, `POST /v1/cards`                         | Manual wallet: create, search, favourites, tags                           |
| `POST /v1/scans` and the review flow                      | Mock reader, checksum check, retry, and dead letter                       |
| Assets, shares, exchange, `PATCH /v1/me`                  | Assets can be presigned. Shares, exchange, and profile edits are `501`    |
| `GET /v1/auth/oidc/*`                                     | `501` `identity_provider_unconfigured` until `OIDC_*` is set              |
| `GET /health`                                             | Postgres, Redis, storage, and queue                                       |
| `GET /docs`                                               | Swagger, off when `NODE_ENV=production`                                   |
| Web `/register`, `/login`, `/wallet`                      | Working, including loading, empty, validation, denied, and network states |
| Flutter                                                   | The same three screens. Tokens live in secure storage                     |
| Image worker                                              | Orient, contrast, thumbnail, and grounded fields. No live OCR provider    |

## Local setup

Requirements: Node.js 22, pnpm 10, Docker, and Flutter 3.47.9 if you want the mobile app. Python 3.12 and `uv` run the worker checks.

```bash
cp .env.example .env
# Replace every placeholder. Do not commit .env.
docker compose --env-file .env -f infra/docker-compose.yml up -d
pnpm install
pnpm --filter @softxu/api exec prisma migrate deploy
pnpm --filter @softxu/api dev
pnpm --filter @softxu/web dev
```

The API listens on port 3001. The web app listens on port 3000 and proxies `/api` to the API so the refresh cookie stays on the web origin. Mobile calls the API directly:

```bash
cd apps/mobile
flutter run --dart-define=API_ORIGIN=http://localhost:3001
```

Use `http://10.0.2.2:3001` from an Android emulator. Debug builds allow local HTTP. A release build expects HTTPS.

Empty `S3_ACCESS_KEY_ID` or `S3_SECRET_ACCESS_KEY` selects the in-memory storage adapter. An empty `SQS_ENDPOINT` selects the in-memory queue. Fill those values, and the MinIO and ElasticMQ URLs in `.env.example`, when you want the Compose services. ElasticMQ does not authenticate; the client sends a non-secret local placeholder only when a key is blank and an endpoint is set.

Optional demo user, with the password coming from the environment:

```bash
SEED_DEMO=true DEMO_USER_EMAIL=you@example.com DEMO_USER_PASSWORD='choose-a-password' \
  DEMO_USER_DISPLAY_NAME='Your Name' pnpm --filter @softxu/api exec prisma db seed
```

## Tests

Integration tests need `DATABASE_URL` pointed at a database whose name contains `test`, and `REDIS_URL` on database index `1`. Generate the JWT secrets in the shell. Do not commit them.

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@localhost:5432/softxu_test'
export REDIS_URL='redis://localhost:6379/1'
export JWT_ACCESS_SECRET="$(openssl rand -hex 32)"
export JWT_REFRESH_SECRET="$(openssl rand -hex 32)"
pnpm typecheck
pnpm lint
pnpm test
pnpm test:worker
pnpm test:mobile
```

GitHub Actions runs the TypeScript typecheck, lint, unit tests, and integration tests against Postgres and Redis service containers, plus Ruff, pytest, `dart analyze`, and `flutter test`.

The first migration creates `users`, `user_profiles`, `refresh_tokens`, `audit_logs`, and `idempotency_keys`. The second adds the manual wallet tables. Both are additive. If they have to be undone before any later migration, restore a database snapshot. There is no down migration.

## Out of scope

Phase 2 is the manual wallet. Phase 3 lets someone upload a front and a back, review the mock reading, and save the card. The original object is not rewritten. A real OCR provider is not configured. Camera behaviour on a physical phone is untested. Phases 4–7 are not started: templates, public card pages, sharing, QR exchange, BLE, NFC, account export, and a hosted deploy. Fly, AWS, and Terraform are not part of this change.
