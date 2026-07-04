# Giggo Live Payment Path

This is the production path for moving Giggo from mock payments to real Stripe payments.

## Where The Payment Path Comes From

Use Stripe Dashboard and Stripe Docs:

- Stripe Dashboard: create the Stripe account, get API keys, configure Connect, create webhook endpoints, and review live payments.
- Stripe Connect: marketplace/provider onboarding and payouts.
- Stripe Checkout setup mode or SetupIntents: secure card setup without storing card numbers in Giggo.
- PaymentIntents with Connect: charge clients and route funds to providers.
- Webhooks: update Giggo records when payments, disputes, setup sessions, or connected accounts change.

Official docs:

- https://docs.stripe.com/connect
- https://docs.stripe.com/connect/onboarding
- https://docs.stripe.com/connect/marketplace/tasks/accept-payment
- https://docs.stripe.com/payments/save-and-reuse
- https://docs.stripe.com/webhooks

## Current Status In This Repo

Already started:

- Server switches between mock mode and Stripe mode with `STRIPE_SECRET_KEY`.
- Provider Connect account creation exists at `POST /api/providers/connect-account`.
- Provider onboarding link creation exists at `POST /api/providers/:providerUid/onboarding-link`.
- Client secure card setup session exists at `POST /api/payments/setup-card-session`.
- Card setup status exists at `GET /api/payments/setup-card-status/:userUid`.
- Escrow authorization exists at `POST /api/payments/escrow-authorize`.
- Webhook handler exists at `POST /api/payments/webhook`.
- The Flutter app calls these backend endpoints through `GigRepository`.
- Local file-backed server persistence exists for payment/provider/customer records during development.
- Optional Firestore-backed server persistence exists for production deployment.
- Stripe mode now requires a saved customer payment method instead of using a hardcoded test payment method.
- Backend deployment files exist for Docker hosts and Render.

## Missing Before Live Payments

- Deploy with `GIGGO_STORE_DRIVER=firestore` and Firebase Admin credentials.
- Deploy the backend to a public HTTPS host.
- Set `CORS_ORIGINS` to the production app domains.
- Decide whether booking payments should be confirmed off-session with saved payment methods or client-confirmed with Stripe's hosted/embedded payment UI.
- Decide the Connect charge type:
  - Destination charges for a single provider per booking.
  - Separate charges and transfers if Giggo must hold funds until completion before transferring to providers.
- Add a true release flow:
  - If using separate charges and transfers, create the transfer only after service completion.
  - If using destination charges, define what "release" means because funds are already routed by Stripe.
- Add webhook handling for:
  - `checkout.session.completed`
  - `setup_intent.succeeded`
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `payment_intent.canceled`
  - `charge.dispute.created`
  - `account.updated`
- Verify webhook signatures in production with `STRIPE_WEBHOOK_SECRET`.
- Store only Stripe IDs, card brand, and last 4 digits. Never store full card numbers, CVC, or raw payment details.
- Add refund and dispute actions for admins/support.
- Add provider payout status to the provider settings page.
- Add clear receipts and transaction history for clients and providers.
- Add production environment variables:
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `APP_BASE_URL`
  - production Firebase/Admin credentials or deployment-specific auth.
- Test Stripe in test mode end to end before switching to live mode.

## Suggested Build Order

1. Persist payment/customer/provider records in Firestore or a database.
2. Finalize the booking payment confirmation model: saved off-session method or client-confirmed hosted/embedded payment UI.
3. Choose destination charges or separate charges and transfers.
4. Implement real escrow release/refund/dispute endpoints.
5. Add webhook-driven status updates to Firestore.
6. Add admin/support views for payment problems.
7. Run Stripe test-mode transactions and webhook tests.
8. Switch environment keys to live Stripe keys only after test mode is complete.
