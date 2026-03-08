import 'package:flutter/material.dart';

import '../models/gig.dart';
import '../services/gig_repository.dart';

class GigDetailScreen extends StatefulWidget {
  const GigDetailScreen({
    super.key,
    required this.gig,
    required this.repository,
  });

  final Gig gig;
  final GigRepository repository;

  @override
  State<GigDetailScreen> createState() => _GigDetailScreenState();
}

class _GigDetailScreenState extends State<GigDetailScreen> {
  Future<void> _createEscrow() async {
    final payment = await widget.repository.createEscrow(
      gigId: widget.gig.id,
      amount: widget.gig.price,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Escrow ${payment.id} created. Fund to secure payment.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWork = widget.repository.canCurrentUserWorkGig(widget.gig);
    final restricted = widget.repository.restrictedReason(widget.gig);
    final fee = widget.repository.platformFeeFor(widget.gig.price);
    final payout = widget.repository.workerPayoutFor(widget.gig.price);

    return Scaffold(
      appBar: AppBar(title: const Text('Gig Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.gig.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${widget.gig.category} • ${widget.gig.location}'),
          const SizedBox(height: 4),
          Text('Provider: ${widget.gig.providerName}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Age ${widget.gig.minAge}+')),
              if (widget.gig.isLateNight) const Chip(label: Text('Late-night')),
              if (widget.gig.requiresBackgroundCheck)
                const Chip(label: Text('Background Check')),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.gig.description),
          if (restricted != null) ...[
            const SizedBox(height: 12),
            Text(
              restricted,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${widget.gig.price.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escrow protects both sides: buyer funds first, provider is paid after completion.',
                  ),
                  const SizedBox(height: 10),
                  Text('Platform fee (15%): \$${fee.toStringAsFixed(2)}'),
                  Text(
                      'Estimated worker payout: \$${payout.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: canWork ? _createEscrow : null,
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      canWork
                          ? 'Accept & Start Escrow'
                          : 'Not Eligible for this Gig',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
