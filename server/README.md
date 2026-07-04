# Giggo Server (Node + Express)

Backend API for gigs and escrow status transitions.

## Run

```bash
npm install
npm start
```

Server runs on `http://localhost:4000` by default.

## Environment

Copy the sample file and set values:

```bash
cp .env.example .env
```

Required for Stripe mode:

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `APP_BASE_URL`
- `CORS_ORIGINS`

If `STRIPE_SECRET_KEY` is missing, server runs in mock payments mode.

Persistence:

- `GIGGO_STORE_DRIVER=file` keeps development state in `src/data/runtime-store.json`.
- `GIGGO_STORE_DRIVER=firestore` stores server payment/provider/customer state in Firestore.
- Optional Firestore location settings:
  - `GIGGO_STORE_COLLECTION=_serverState`
  - `GIGGO_STORE_DOCUMENT=runtime`

For deployed production, use `GIGGO_STORE_DRIVER=firestore` and configure the host with Firebase Admin credentials or an environment that supports Application Default Credentials.

## Deploy

The server can be deployed as a normal Node web service.

### Render

This repo includes `render.yaml` at the project root.

1. Push the repo to GitHub.
2. In Render, create a Blueprint from the repo.
3. Set the required environment variables:
   - `APP_BASE_URL`
   - `CORS_ORIGINS`
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - Firebase Admin credentials or a deployment environment that supports Application Default Credentials
4. Confirm `/health` returns `status: ok`.

### Docker Hosts / Cloud Run

This repo includes `server/Dockerfile`.

Build from the `server` directory:

```bash
docker build -t giggo-api .
```

Run locally:

```bash
docker run --env-file .env -p 4000:4000 giggo-api
```

### Stripe Webhook After Deploy

After the backend has a public HTTPS URL, create the Stripe webhook endpoint:

```text
https://YOUR_BACKEND_DOMAIN.com/api/payments/webhook
```

Use the webhook signing secret from that deployed endpoint as `STRIPE_WEBHOOK_SECRET`.

## Stripe Webhook Test (CLI)

1. Start server:

```bash
npm run dev
```

2. In a separate terminal, start Stripe listener and forward events:

```bash
stripe listen --forward-to http://localhost:4000/api/payments/webhook
```

3. Copy the printed webhook secret (`whsec_...`) into `.env` as `STRIPE_WEBHOOK_SECRET` and restart server.

4. Trigger a test event:

```bash
stripe trigger payment_intent.succeeded
```

5. Optional extra tests:

```bash
stripe trigger payment_intent.payment_failed
stripe trigger charge.dispute.created
```

## API Endpoints

- `GET /health`
- `GET /api/payments/records`
- `GET /api/gigs`
- `POST /api/gigs`
- `GET /api/escrows`
- `POST /api/escrows`
- `PATCH /api/escrows/:id/fund`
- `PATCH /api/escrows/:id/release`
- `PATCH /api/escrows/:id/dispute`
- `POST /api/providers/connect-account`
- `POST /api/providers/:providerUid/onboarding-link`
- `POST /api/payments/escrow-authorize`
- `POST /api/payments/escrow-release`
- `POST /api/payments/webhook`
