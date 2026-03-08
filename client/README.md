# Giggo (Flutter)

Giggo is a local gig marketplace where teens and adults can offer services like dog walking, landscaping, and car detailing.

## MVP Features

- Browse local service listings by category
- Post a new service
- View gig details
- Create an escrow payment from a gig
- Manage escrow state (`Pending Funding -> Funded -> Released`) with dispute option

> Note: This app now calls the local Giggo backend API for gigs and escrow status updates. If the API is unavailable, it falls back to in-memory data.

## Run Locally

1. Start backend (`../server`):

```bash
npm install
npm start
```

2. Start Flutter app (this folder):

```bash
flutter pub get
flutter run
```

3. Ensure API base URL in `lib/services/gig_repository.dart` points to your backend (`http://localhost:4000` by default).

## Suggested Production Stack

- Flutter app (this client)
- Backend API (`server/` Node + Express)
- Payment provider with hold/release flow
- Identity verification + moderation for teen/adult safety
- Escrow dispute workflow with admin review
