# Giggo App Store Readiness Checklist

This checklist tracks what is missing before submitting Giggo to the Apple App Store and Google Play Store.

## Payments

- [x] Basic Stripe server package added.
- [x] Provider Connect account endpoint started.
- [x] Provider onboarding link endpoint started.
- [x] Client card setup session endpoint started.
- [x] Payment webhooks endpoint started.
- [x] Local development persistence added for Stripe records.
- [x] Stripe mode no longer uses a hardcoded test payment method for escrow authorization.
- [x] Optional Firestore server persistence driver added.
- [ ] Deploy backend with `GIGGO_STORE_DRIVER=firestore` and Firebase Admin credentials.
- [ ] Finalize saved-payment-method flow versus client-confirmed Stripe checkout/payment UI.
- [ ] Choose destination charges or separate charges and transfers.
- [ ] Implement real escrow release after service completion.
- [ ] Implement refunds, disputes, and failed-payment recovery.
- [ ] Show payment history and receipts to clients/providers.
- [ ] Confirm app-store payment rules for service payments and provider subscription.

## Legal And Policy

- [x] In-app starter Privacy Policy page exists.
- [x] In-app starter Terms page exists.
- [x] In-app account deletion exists in Settings.
- [ ] Replace starter policy text with lawyer-reviewed production Privacy Policy.
- [ ] Replace starter terms with lawyer-reviewed production Terms of Service.
- [x] Publish public Privacy Policy URL: `https://giggo-8a302.web.app/privacy`.
- [x] Publish public Terms URL: `https://giggo-8a302.web.app/terms`.
- [x] Publish public Support URL: `https://giggo-8a302.web.app/support`.
- [x] Publish public Account/Data Deletion URL for Google Play: `https://giggo-8a302.web.app/delete-account`.
- [ ] Add production support email and company/developer contact info.
- [ ] Complete Apple App Privacy details.
- [ ] Complete Google Play Data Safety form.

## User Safety And Moderation

- [x] User report flow exists for provider store/conversation areas.
- [x] Block/unblock behavior started.
- [x] Parent approval flow started for minors.
- [ ] Add admin moderation dashboard or support queue.
- [ ] Add content filtering for listings, stores, and messages.
- [ ] Add report status tracking and reviewer notes.
- [ ] Add user suspension/restriction tooling.
- [x] Add published community/safety rules: `https://giggo-8a302.web.app/safety`.
- [ ] Add audit logs for minor bookings and parent approvals.
- [x] Add emergency/support escalation copy for unsafe service situations.

## Accounts And Privacy

- [x] Email/password account creation exists.
- [x] Parent account setup exists for under-18 users.
- [x] Logout exists.
- [x] In-app delete account flow exists.
- [ ] Add re-authentication handling for account deletion when Firebase requires recent login.
- [x] Add public deletion request web form or support flow.
- [x] Document data retention for payment, fraud, tax, and safety records: `docs/data_retention_policy.md`.
- [ ] Add export/download-my-data plan if required by operating regions.

## Production Backend

- [x] Firebase integration exists.
- [x] Express server exists.
- [x] Dockerfile added for backend deployment.
- [x] Render blueprint added for backend deployment.
- [x] Production CORS origin setting added.
- [ ] Deploy backend to a production HTTPS host.
- [x] Server can use Firestore-backed persistence for production.
- [ ] Enable Firestore-backed persistence in the deployed backend.
- [ ] Set `CORS_ORIGINS` on the deployed backend.
- [x] Add rate limiting and abuse protection.
- [x] Add server-side auth verification for protected API routes.
- [ ] Add server logs, error tracking, and monitoring.
- [x] Add backups and data retention policy: `docs/data_retention_policy.md`.
- [ ] Add production environment variables and secret management.

## Mobile Release Build

- [x] Flutter app builds/runs on web/debug.
- [ ] Confirm Android package name and app label. App label is `Giggo`; package still needs a production Firebase Android app before changing from `com.example.giggo`.
- [ ] Confirm iOS bundle identifier and app display name. Display name is `Giggo`; bundle identifier still needs a production Firebase iOS app before changing from `com.example.giggo`.
- [ ] Replace default launcher icons with final Giggo icon.
- [ ] Replace default splash/launch screens with final Giggo branding.
- [ ] Configure Android release signing.
- [ ] Configure iOS signing and Apple Developer team.
- [ ] Run `flutter analyze` with no errors.
- [ ] Run Android release build.
- [ ] Run iOS release build on macOS/Xcode.
- [ ] Test on real Android device.
- [ ] Test on real iPhone.

## Store Listing

- [ ] App name and subtitle/short description.
- [ ] Full app description.
- [ ] Keywords/category.
- [ ] App screenshots for required Apple sizes.
- [ ] App screenshots for Google Play.
- [ ] App preview video if wanted.
- [x] Support URL: `https://giggo-8a302.web.app/support`.
- [ ] Marketing URL if wanted.
- [x] Privacy Policy URL: `https://giggo-8a302.web.app/privacy`.
- [ ] Age rating questionnaire.
- [ ] Demo/reviewer account credentials.
- [x] Review notes explaining parent approval, payments, moderation, and provider onboarding: `docs/app_review_notes.md`.

## Final Review

- [x] No placeholder support text remains.
- [ ] No test Stripe keys in production.
- [ ] No mock payment mode in production.
- [ ] No debug banner or debug-only screens.
- [ ] Backend is live during app review.
- [x] All non-obvious features are explained in review notes.
