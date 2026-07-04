import 'package:flutter/material.dart';

enum PublicInfoType {
  support,
  deleteAccount,
  safetyRules,
}

class PublicInfoScreen extends StatelessWidget {
  const PublicInfoScreen({
    super.key,
    required this.type,
  });

  final PublicInfoType type;

  String get _title {
    switch (type) {
      case PublicInfoType.support:
        return 'Giggo Support';
      case PublicInfoType.deleteAccount:
        return 'Delete Your Giggo Account';
      case PublicInfoType.safetyRules:
        return 'Giggo Safety Rules';
    }
  }

  IconData get _icon {
    switch (type) {
      case PublicInfoType.support:
        return Icons.support_agent_outlined;
      case PublicInfoType.deleteAccount:
        return Icons.delete_outline;
      case PublicInfoType.safetyRules:
        return Icons.health_and_safety_outlined;
    }
  }

  List<({String heading, String body})> get _sections {
    switch (type) {
      case PublicInfoType.support:
        return const [
          (
            heading: 'Need help with Giggo?',
            body:
                'For account access, bookings, provider stores, payments, parent approval, or safety reports, open Giggo and go to Settings or the relevant conversation/store to use the available support, report, block, and account tools.',
          ),
          (
            heading: 'Payment and payout questions',
            body:
                'Client payments, saved card setup, provider onboarding, and payout details are handled through secure Stripe-hosted flows where available. Never share full card numbers, passwords, or one-time login codes in messages.',
          ),
          (
            heading: 'Safety concerns',
            body:
                'If a service situation feels unsafe, leave the situation and contact local emergency services first. You can also report providers, listings, stores, messages, or accounts inside Giggo for review.',
          ),
          (
            heading: 'Unsafe service escalation',
            body:
                'For immediate danger, call local emergency services before using Giggo support. After you are safe, report the booking, conversation, provider store, or account in the app and include the service name, date, location, and any messages that help explain what happened.',
          ),
          (
            heading: 'What Giggo can review',
            body:
                'Giggo can review reports, messages, provider stores, listings, parent approval records, and payment or booking details when investigating unsafe behavior, fraud, harassment, or policy violations.',
          ),
        ];
      case PublicInfoType.deleteAccount:
        return const [
          (
            heading: 'Delete from inside the app',
            body:
                'Sign in to Giggo, open Settings, go to Legal and account, then choose Delete account. Giggo will mark your account and service page as deleted and sign you out.',
          ),
          (
            heading: 'What deletion does',
            body:
                'Your public profile and service page are removed from normal app use. Some records may be retained when required for payment processing, fraud prevention, tax, safety, dispute, or legal reasons.',
          ),
          (
            heading: 'If Firebase asks you to sign in again',
            body:
                'For security, account deletion can require a recent login. Log out, sign back in, and retry Delete account from Settings.',
          ),
        ];
      case PublicInfoType.safetyRules:
        return const [
          (
            heading: 'Respectful marketplace behavior',
            body:
                'Treat clients, providers, parents, and support reviewers with respect. Harassment, threats, hate, intimidation, sexual content involving minors, spam, impersonation, and misleading listings are not allowed.',
          ),
          (
            heading: 'Accurate service posts',
            body:
                'Providers must describe services, prices, availability, locations, qualifications, and requirements honestly. Do not post services that are illegal, unsafe, adult-only, counterfeit, stolen, or outside your ability to complete.',
          ),
          (
            heading: 'Payments and off-platform activity',
            body:
                'Use the payment and booking tools Giggo provides when they are available. Do not pressure users to share full card details, passwords, one-time codes, government IDs, or private banking information in chat.',
          ),
          (
            heading: 'Minors and parent approval',
            body:
                'Users under 18 must use the parent approval flow when required. Parents or guardians are responsible for reviewing service requests and approving whether the minor may participate.',
          ),
          (
            heading: 'Unsafe situations',
            body:
                'If a service situation feels unsafe, leave if you can and contact local emergency services first. Report the provider, client, message, listing, or store in Giggo so the account can be reviewed.',
          ),
          (
            heading: 'Enforcement',
            body:
                'Giggo may remove content, limit visibility, block bookings, suspend accounts, or preserve records when needed to protect users, investigate disputes, prevent fraud, or follow legal requirements.',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_icon, size: 42, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: July 4, 2026',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in _sections) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(section.body),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
