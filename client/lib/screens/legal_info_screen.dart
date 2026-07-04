import 'package:flutter/material.dart';

enum LegalInfoType {
  privacy,
  terms,
}

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({
    super.key,
    required this.type,
  });

  final LegalInfoType type;

  String get _title =>
      type == LegalInfoType.privacy ? 'Privacy Policy' : 'Terms of Service';

  List<({String heading, String body})> get _sections {
    if (type == LegalInfoType.privacy) {
      return const [
        (
          heading: 'Information we collect',
          body:
              'Giggo collects account details, profile information, service listings, booking details, messages, payment status, device diagnostics, and trust/safety reports needed to operate the marketplace.',
        ),
        (
          heading: 'How we use information',
          body:
              'We use information to create accounts, show provider stores, support messaging and bookings, process payments, prevent abuse, improve reliability, and respond to support or legal requests.',
        ),
        (
          heading: 'Payments',
          body:
              'Payment and payout processing may be handled by payment providers such as Stripe, Apple, or Google. Giggo stores payment status and related identifiers, not full card numbers.',
        ),
        (
          heading: 'Safety and moderation',
          body:
              'Reports, blocked-user records, and related content may be reviewed to protect users, investigate disputes, and enforce marketplace rules.',
        ),
        (
          heading: 'Your choices',
          body:
              'You can update profile details, block users, report content, log out, or request account deletion from inside the app.',
        ),
        (
          heading: 'Contact',
          body:
              'For privacy or support questions, contact the Giggo support team. Replace this placeholder with the production support email before store submission.',
        ),
      ];
    }

    return const [
      (
        heading: 'Marketplace role',
        body:
            'Giggo helps clients discover local providers, message them, book services, and use supported payment flows. Providers are responsible for accurately describing their services and availability.',
      ),
      (
        heading: 'User responsibilities',
        body:
            'Users must provide accurate information, follow local laws, avoid unsafe or abusive behavior, and keep all marketplace communication respectful.',
      ),
      (
        heading: 'Payments and fees',
        body:
            'Service payments, platform fees, provider payouts, refunds, disputes, and subscriptions are subject to the payment flow shown in the app and any applicable payment-provider terms.',
      ),
      (
        heading: 'Prohibited content',
        body:
            'Do not post illegal, misleading, hateful, explicit, unsafe, or spam content. Giggo may remove content or restrict accounts that violate marketplace rules.',
      ),
      (
        heading: 'Reports and enforcement',
        body:
            'Users can report listings, stores, messages, or accounts. Giggo may review reports and take action including warnings, content removal, blocking, or account restrictions.',
      ),
      (
        heading: 'Important placeholder',
        body:
            'These terms are starter app text for development and store-readiness work. Replace them with lawyer-reviewed production terms before public launch.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Last updated: June 30, 2026',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            );
          }

          final section = _sections[index - 1];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.heading,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(section.body),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
