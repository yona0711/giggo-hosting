import 'package:flutter/material.dart';

import '../services/gig_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  Widget build(BuildContext context) {
    final user = repository.profileForView;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          title: Text('Your Profile'),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.15),
                            child: Text(
                              user.name.characters.first,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(user.bio),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                              label:
                                  Text('⭐ ${user.rating.toStringAsFixed(1)}')),
                          Chip(
                              label: Text('✅ ${user.completedGigs} completed')),
                          Chip(
                            label: Text(user.isVerified
                                ? 'Verified Badge'
                                : 'Not Verified'),
                          ),
                          Chip(label: Text('Age ${user.ageBadge}')),
                          Chip(
                            label: Text(user.backgroundChecked
                                ? 'Background Checked'
                                : 'Background Check Optional'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skills',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.skills
                            .map((skill) => Chip(label: Text(skill)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (user.isTeen)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parent Controls (13–17)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                            'Monitoring: ${user.hasParentMonitoring ? 'Enabled' : 'Off'}'),
                        Text(
                          'Payout approval: ${user.parentPayoutApproval ? 'Required' : 'Not required'}',
                        ),
                        Text(
                            'Weekly payout limit: \$${user.payoutLimitPerWeek}'),
                        const SizedBox(height: 8),
                        const Text(
                          'Teen accounts have category and time restrictions for safety.',
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Center',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text('• In-app messaging only'),
                      const Text('• Emergency safety button'),
                      const Text('• AI unsafe-language monitoring'),
                      const Text('• Check-in/check-out location prompts'),
                      const Text('• Two-way reviews and reporting'),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
