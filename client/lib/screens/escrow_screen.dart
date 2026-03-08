import 'package:flutter/material.dart';

import '../models/escrow_payment.dart';
import '../services/gig_repository.dart';

class EscrowScreen extends StatefulWidget {
  const EscrowScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  State<EscrowScreen> createState() => _EscrowScreenState();
}

class _EscrowScreenState extends State<EscrowScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEscrows();
  }

  Future<void> _loadEscrows() async {
    await widget.repository.fetchEscrows();
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  String statusText(EscrowStatus status) {
    switch (status) {
      case EscrowStatus.pendingFunding:
        return 'Pending Funding';
      case EscrowStatus.funded:
        return 'Funded';
      case EscrowStatus.released:
        return 'Released to Provider';
      case EscrowStatus.disputed:
        return 'Disputed';
    }
  }

  Color statusColor(EscrowStatus status, BuildContext context) {
    switch (status) {
      case EscrowStatus.pendingFunding:
        return Colors.orange;
      case EscrowStatus.funded:
        return Colors.blue;
      case EscrowStatus.released:
        return Colors.green;
      case EscrowStatus.disputed:
        return Theme.of(context).colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.repository.payments;

    return Scaffold(
      appBar: AppBar(title: const Text('Payments & Escrow')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How Giggo escrow works',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text('1) Customer posts a gig and pays upfront.'),
                        const Text('2) Funds stay protected in escrow.'),
                        const Text(
                            '3) Worker completes task and customer confirms.'),
                        const Text(
                            '4) Giggo releases payout minus platform fee.'),
                        const SizedBox(height: 8),
                        Text(
                          'Commission model: ${(widget.repository.platformCommissionRate * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (payments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No escrow payments yet.'),
                    ),
                  ),
                ...payments.map((payment) {
                  final fee = widget.repository.platformFeeFor(payment.amount);
                  final payout =
                      widget.repository.workerPayoutFor(payment.amount);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Escrow ${payment.id}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                'Amount: \$${payment.amount.toStringAsFixed(2)}'),
                            Text('Platform fee: \$${fee.toStringAsFixed(2)}'),
                            Text(
                                'Worker payout: \$${payout.toStringAsFixed(2)}'),
                            const SizedBox(height: 6),
                            Text(
                              statusText(payment.status),
                              style: TextStyle(
                                color: statusColor(payment.status, context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: payment.status ==
                                          EscrowStatus.pendingFunding
                                      ? () async {
                                          await widget.repository
                                              .fundEscrow(payment.id);
                                          setState(() {});
                                        }
                                      : null,
                                  child: const Text('Fund'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      payment.status == EscrowStatus.funded
                                          ? () async {
                                              await widget.repository
                                                  .releaseEscrow(payment.id);
                                              setState(() {});
                                            }
                                          : null,
                                  child: const Text('Release'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      payment.status == EscrowStatus.released
                                          ? null
                                          : () async {
                                              await widget.repository
                                                  .disputeEscrow(payment.id);
                                              setState(() {});
                                            },
                                  child: const Text('Dispute'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
