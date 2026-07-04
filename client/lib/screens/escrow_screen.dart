import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    return '$month/$day/$year';
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

  Future<Uint8List> _generateTaxPdf(
      List<EscrowPayment> releasedPayments,
      Map<int, double> taxTotalsByYear,
      double totalThisMonth,
      String totalLabel,
      String heading,
      String commissionModel,
      BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(heading,
              style:
                  pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text('Commission model: $commissionModel',
              style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 24),
          pw.Text('Total for this month: $totalLabel',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text('Yearly totals',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: taxTotalsByYear.entries
                  .toList()
                  .reversed
                  .map((entry) => pw.Text(
                      '${entry.key}: \$${entry.value.toStringAsFixed(2)}'))
                  .toList()),
          pw.SizedBox(height: 20),
          pw.Text('Payments',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: releasedPayments.map((payment) {
              final serviceLabel = payment.serviceTitle?.isNotEmpty == true
                  ? payment.serviceTitle!
                  : 'service';
              final dateLabel = payment.createdAt != null
                  ? _formatDate(payment.createdAt!)
                  : 'unknown date';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  '\$${payment.amount.toStringAsFixed(2)} on $dateLabel for $serviceLabel',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _printTaxSummary(
      List<EscrowPayment> releasedPayments,
      Map<int, double> taxTotalsByYear,
      double totalThisMonth,
      String amountText,
      BuildContext context) async {
    final totalLabel = '\$${amountText} made this month';
    final pdfBytes = await _generateTaxPdf(
      releasedPayments,
      taxTotalsByYear,
      totalThisMonth,
      totalLabel,
      'Giggo Tax Summary',
      widget.repository.platformCommissionRate == 0
          ? '0% (Giggo Pro active)'
          : '${(widget.repository.platformCommissionRate * 100).toStringAsFixed(0)}%',
      context,
    );
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payments = widget.repository.payments;
    final releasedPayments = payments
        .where((payment) => payment.status == EscrowStatus.released)
        .toList();
    final totalThisMonth = releasedPayments.fold<double>(
        0, (sum, payment) => sum + payment.amount);
    final amountText = totalThisMonth == totalThisMonth.truncateToDouble()
        ? totalThisMonth.toStringAsFixed(0)
        : totalThisMonth.toStringAsFixed(2);
    final taxTotalsByYear = widget.repository.totalReceivedByYear;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 560),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'Payments',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.background,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How Giggo escrow works',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                  '1) Customer posts a service listing and pays upfront.'),
                              const Text('2) Funds stay protected in escrow.'),
                              const Text(
                                  '3) Worker completes task and customer confirms.'),
                              const Text(
                                  '4) Giggo releases payout minus platform fee.'),
                              const SizedBox(height: 14),
                              Text(
                                widget.repository.platformCommissionRate == 0
                                    ? 'Commission model: 0% with Giggo Pro'
                                    : 'Commission model: ${(widget.repository.platformCommissionRate * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${amountText}',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'made this month',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (releasedPayments.isEmpty)
                          Text(
                            'No completed payments yet. Once money is released, Giggo will keep a record for tax reporting.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tax history',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.print),
                                  label: const Text('Print 1099'),
                                  onPressed: () => _printTaxSummary(
                                    releasedPayments,
                                    taxTotalsByYear,
                                    totalThisMonth,
                                    amountText,
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (taxTotalsByYear.isNotEmpty)
                                ...taxTotalsByYear.entries
                                    .toList()
                                    .reversed
                                    .map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${entry.key}: \$${entry.value.toStringAsFixed(2)} total',
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }),
                              const SizedBox(height: 12),
                              ...releasedPayments.map((payment) {
                                final serviceLabel =
                                    payment.serviceTitle?.isNotEmpty == true
                                        ? payment.serviceTitle!
                                        : 'service';
                                final dateLabel = payment.createdAt != null
                                    ? _formatDate(payment.createdAt!)
                                    : 'unknown date';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '\$${payment.amount.toStringAsFixed(0)} on $dateLabel for $serviceLabel',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
