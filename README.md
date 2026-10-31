# businesscard

Softxu is a business card wallet and networking platform for Softxu Technologies. This repository is the modular monolith described in the architecture plan: a NestJS API, a Next.js portal, a Flutter app, and a Python image worker. Phase 1 is accounts and an empty wallet. Phase 2 adds manual cards. Phase 3 adds a scan that uses a mock reader. Phase 4 adds digital cards and a public page. Phase 5 adds a share link that expires and can be revoked. Phase 6 adds a short-lived QR exchange between two signed-in people. Later phases are not in this tree.

## What works

A new person can register, sign in, and open a wallet on the web app and on the Flutter app. On the web they can add a card, edit it, search, mark a favourite, tag it, publish a digital card, share a link to chosen fields, and exchange a card with a short-lived QR. The Flutter wallet lists card titles. The API checks the access token on every protected route, so one account cannot read another account's card or profile. Refresh tokens rotate and are stored only as an HMAC. Passwords are Argon2id hashes.

Local infrastructure is Docker Compose: Postgres 16, Redis 7, MinIO, and ElasticMQ. Nothing here provisions Fly or AWS, and there is no Terraform.

| Surface                                                                           | Status                                                                 |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `POST /v1/auth/register`, `/login`, `/refresh`, `/logout`                         | Working                                                                |
| `GET /v1/me`                                                                      | The caller only                                                        |
| `GET /v1/cards`, `POST /v1/cards`                                                 | Manual wallet: create, search, favourites, tags                        |
| `POST /v1/scans` and the review flow                                              | Mock reader, checksum check, retry, and dead letter                    |
| Digital cards, templates, `/v1/public/cards/:slug`                                | Two templates, design, publish, and QR, PNG, PDF, vCard export         |
| Share links, `/v1/public/shares/:token`, `/s/[token]`                             | Hashed token, expiry, revoke, optional PIN, vCard, and claim           |
| `POST /v1/exchange-sessions` and `/exchange/[id]`                                 | QR or link session, join, consent, and a snapshot after consent        |
| Assets, `PATCH /v1/me`                                                            | Assets can be presigned. Profile edits are `501`                       |
| `GET /v1/auth/oidc/*`                                                             | `501` `identity_provider_unconfigured` until `OIDC_*` is set           |
| `GET /health`                                                                     | Postgres, Redis, storage, and queue                                    |
| `GET /docs`                                                                       | Swagger, off when `NODE_ENV=production`                                |
| Web `/register`, `/login`, `/wallet`, `/c/[slug]`, `/s/[token]`, `/exchange/[id]` | Working, with loading, empty, validation, denied, and network states   |
| Flutter                                                                           | Register, sign in, and an empty or titled wallet. No exchange screen   |
| Image worker                                                                      | Orient, contrast, thumbnail, and grounded fields. No live OCR provider |

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

Migrations are additive: accounts, the manual wallet, scan assets, card templates, share links, and exchange sessions. If they have to be undone before any later migration, restore a database snapshot. There is no down migration.

## Out of scope

Phase 6 lets two signed-in people exchange through a QR or the same short-lived link. The QR encodes `https://{publicHost}/exchange/{id}?c={code}` and never the contact record. The public card QR at `/c/{slug}` is a different code. The session lasts 3 minutes unless a shorter or longer window, from 30 seconds to 10 minutes, is requested. Stop, decline, or expiry saves nothing. A one-way exchange snapshots the offered card into the recipient wallet only after they accept. A mutual exchange writes neither snapshot until both people have accepted and each has chosen a card. The server copies the selected card. The client does not post the other person's fields.

Android can advertise BLE in the foreground with a service UUID and a short code. iOS does not allow an app to advertise an arbitrary BLE service in the background, and this build does not ship a foreground advertiser. NFC host-card emulation is not available to third-party apps on iOS, and Android host-card emulation needs a foreground service this build does not include. `method` `ble` or `nfc` returns 400 and says to use QR. There is no tap-to-transfer. If a radio path is added later, a failure falls back to this QR.

The Flutter app does not open an exchange. The web join page is the stand-in for a camera scanner: open the QR URL, or paste the code. A real OCR provider is not configured. Camera behaviour on a physical phone is untested. Text delivery stays on the mock sender. Phase 7 is not started: account export, account deletion, an offline cache, OpenTelemetry, a load test, and a hosted deploy. Fly, AWS, and Terraform are not part of this change.
