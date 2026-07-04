import 'package:flutter/material.dart';

import '../models/gig.dart';
import '../services/gig_repository.dart';
import 'service_public_page_screen.dart';

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
  String _formatSlot(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$m/$d/${value.year} $hh:$mm';
  }

  Future<void> _createEscrow() async {
    final payment = await widget.repository.createEscrow(
      gigId: widget.gig.id,
      amount: widget.gig.price,
      serviceTitle: widget.gig.title,
      providerUid: widget.gig.providerUid,
      clientUid: widget.repository.currentUserUid,
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

  Future<void> _openProviderServicePage() async {
    final providerUid = widget.gig.providerUid;
    if (providerUid == null || providerUid.isEmpty) {
      return;
    }

    final page = await widget.repository.fetchOrCreateServicePageForGig(
      widget.gig,
    );
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicePublicPageScreen(
          repository: widget.repository,
          shareSlug: page.shareSlug,
          previewPage: page,
        ),
      ),
    );
  }

  Future<void> _messageProvider() async {
    final providerUid = widget.gig.providerUid;
    if (providerUid == null || providerUid.isEmpty) {
      return;
    }

    try {
      await widget.repository.sendMessageToProvider(
        providerUid: providerUid,
        providerName: widget.gig.providerName,
        text: 'Hi! I am interested in your service: ${widget.gig.title}',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to provider inbox.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWork = widget.repository.canCurrentUserWorkGig(widget.gig);
    final restricted = widget.repository.restrictedReason(widget.gig);
    final fee = widget.repository.platformFeeFor(widget.gig.price);
    final payout = widget.repository.workerPayoutFor(widget.gig.price);
    final commissionRate = widget.repository.platformCommissionRate;

    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.gig.title,
            textAlign: TextAlign.center,
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
            ],
          ),
          if (widget.gig.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.gig.tags
                  .map(
                    (tag) => Chip(
                      avatar: const Icon(Icons.sell_outlined, size: 16),
                      label: Text(tag),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text(widget.gig.description),
          if (widget.gig.availableSlots.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Provider availability',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.gig.availableSlots
                  .take(10)
                  .map((slot) => Chip(label: Text(_formatSlot(slot))))
                  .toList(),
            ),
          ],
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
          if (widget.gig.providerUid != null &&
              widget.gig.providerUid!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact provider',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask questions, confirm availability, and agree on details before booking.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _messageProvider,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message Provider'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openProviderServicePage,
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('View Service Page'),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.gig.providerUid != null &&
              widget.gig.providerUid!.isNotEmpty)
            const SizedBox(height: 12),
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
                  Text(
                    commissionRate == 0
                        ? 'Platform fee: \$0.00 (Giggo Pro active)'
                        : 'Platform fee (${(commissionRate * 100).toStringAsFixed(0)}%): \$${fee.toStringAsFixed(2)}',
                  ),
                  Text(
                      'Estimated worker payout: \$${payout.toStringAsFixed(2)}'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: canWork ? _createEscrow : null,
                    icon: const Icon(Icons.shield_outlined),
                    label: Text(
                      canWork
                          ? 'Accept & Start Escrow'
                          : 'Not eligible for this service',
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
