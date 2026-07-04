# Giggo Data Retention Policy

This document tracks Giggo's planned production data retention rules. It should be reviewed with legal counsel before public app-store submission.

## Account And Profile Data

- Active account, profile, provider store, service post, and preference data is kept while the account is active.
- When a user deletes their account, Giggo removes the public profile and service page from normal app use.
- Deleted account records may retain a minimal internal identifier, deletion timestamp, and audit metadata needed to prevent abuse, resolve disputes, or comply with legal obligations.

## Payments, Fraud, Tax, And Disputes

- Stripe payment records, payout records, connected account identifiers, dispute records, refund records, and tax-related summaries may be retained as required by Stripe, payment network rules, fraud prevention needs, tax obligations, accounting obligations, and legal claims.
- Giggo should not store full card numbers. Card collection and saved payment methods should remain handled by Stripe-hosted or Stripe-secure flows.
- Payment logs and webhook event references should be retained long enough to reconcile payments, recover failed webhook processing, and investigate disputes.

## Safety, Reports, Blocks, And Moderation

- User reports, blocked-user records, safety review notes, relevant messages, related listing/store snapshots, and booking context may be retained to investigate policy violations, unsafe behavior, harassment, fraud, or repeat abuse.
- Safety records involving minors or parent approvals may be retained when needed to verify consent, investigate reports, or document why a booking was approved or denied.
- Giggo should restrict access to safety records to authorized support, moderation, legal, or engineering staff who need them.

## Parent Approval And Minor Accounts

- Parent approval tokens and pending approval requests should expire when no longer needed.
- Approved or rejected parent approval records may be retained with timestamps, involved account IDs, and the service request context to support safety audits and dispute review.
- Parent and minor account links should be removed from normal app use when either account is deleted, except where retention is required for safety, payment, fraud, tax, or legal reasons.

## Backups And Logs

- Production backups should have a defined retention window and deletion schedule before public launch.
- Server logs should avoid full payment details, secrets, passwords, one-time codes, and unnecessary personal information.
- Error logs should be retained only as long as needed for reliability, security, abuse prevention, or legal needs.

## User Requests

- Users can delete their account in Settings.
- Giggo should provide a support path for deletion problems, privacy questions, and data access/export requests where required by operating region.
- If account deletion requires a recent Firebase login, the app should guide the user to sign out, sign back in, and retry deletion.

## Open Pre-Launch Decisions

- Choose exact retention periods for deleted accounts, reports, payment references, logs, and backups.
- Decide whether Giggo will offer an in-app "download my data" flow at launch or a manual support process first.
- Replace this internal plan with lawyer-reviewed production Privacy Policy and Terms language.
