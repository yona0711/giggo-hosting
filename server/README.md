# Giggo Server (Node + Express)

Backend API for gigs and escrow status transitions.

## Run

```bash
npm install
npm start
```

Server runs on `http://localhost:4000` by default.

## API Endpoints

- `GET /health`
- `GET /api/gigs`
- `POST /api/gigs`
- `GET /api/escrows`
- `POST /api/escrows`
- `PATCH /api/escrows/:id/fund`
- `PATCH /api/escrows/:id/release`
- `PATCH /api/escrows/:id/dispute`
