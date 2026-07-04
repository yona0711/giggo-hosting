# Giggo App Review Notes

Use this text as the starting point for Apple App Review and Google Play review notes.

## App Purpose

Giggo is a local services marketplace. Clients can discover service providers, view live provider store pages, message providers, request services, and use supported payment flows. Providers can create and edit service posts, publish a public store page, manage profile details, and start Stripe onboarding for payments and payouts.

## Reviewer Access

Demo account credentials still need to be created before submission. Use the following public pages during review:

- Privacy Policy: https://giggo-8a302.web.app/privacy
- Terms of Service: https://giggo-8a302.web.app/terms
- Support: https://giggo-8a302.web.app/support
- Account deletion: https://giggo-8a302.web.app/delete-account
- Safety rules: https://giggo-8a302.web.app/safety

## Parent Approval

Giggo includes a parent approval flow for users under 18. During signup, a minor can enter their information and is redirected into parent/guardian setup when age rules require it. The parent account has its own portal, can review pending approvals for the child, and can also search for services independently.

## Payments

Giggo uses Stripe-hosted flows for secure card setup and provider onboarding where available. Card entry is handled by Stripe rather than collecting full card numbers directly inside Giggo. The backend exposes authenticated payment endpoints, verifies Firebase ID tokens, and receives Stripe webhook events for setup, payment, dispute, and account updates.

Before public release, Giggo must switch all Stripe configuration from test mode to live mode, finalize the booking charge/escrow model, and provide reviewer/demo payment instructions.

## Provider Onboarding

Providers can access provider tools after creating an account. The app supports service posts with searchable tags, live provider store pages, profile/store editing, and Stripe Connect onboarding for payout eligibility.

## Moderation And Safety

Giggo includes report and block flows for users, stores, listings, and conversations. Public support and safety pages explain marketplace rules, unsafe service escalation, and emergency-first guidance. Reports may be reviewed using messages, store/listing content, parent approval records, payment records, and booking details.

## Account Deletion

Signed-in users can delete their account from Settings. A public deletion support page is also available for Google Play review. Some records may be retained when required for payment processing, fraud prevention, tax, safety, dispute, or legal reasons.

## Known Pre-Submission Items

- Create demo client, provider, parent, and minor accounts.
- Replace starter legal text with lawyer-reviewed production Privacy Policy and Terms.
- Switch Stripe to live keys before production submission.
- Complete Apple App Privacy and Google Play Data Safety forms.
- Configure Android/iOS release signing and final package/bundle identifiers.
