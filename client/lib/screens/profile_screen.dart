import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme_controller.dart';
import '../models/service_page.dart';
import '../models/service_booking.dart';
import '../models/user_profile.dart';
import '../services/gig_repository.dart';
import 'legal_info_screen.dart';
import 'service_page_editor_screen.dart';
import 'service_public_page_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    this.onLoggedOut,
  });

  final GigRepository repository;
  final VoidCallback? onLoggedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ServicePage? _servicePage;
  bool _loadingPage = true;
  bool _loadingPayoutSetup = false;
  bool _startingPayoutSetup = false;
  bool _updatingSubscription = false;
  bool _deletingAccount = false;
  bool _startingPaymentSetup = false;
  bool _loadingPaymentMethod = false;
  String? _stripeAccountId;
  String? _savedCardBrand;
  String? _savedCardLast4;

  bool get _isBusinessAccount =>
      widget.repository.profileForView.isBusinessAccount;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentMethodStatus();
    if (_isBusinessAccount) {
      _loadServicePage();
      _loadPayoutSetup();
    } else {
      _loadingPage = false;
    }
  }

  Future<void> _loadPayoutSetup() async {
    setState(() => _loadingPayoutSetup = true);
    final accountId = await widget.repository.fetchMyStripeAccountId();
    if (!mounted) {
      return;
    }
    setState(() {
      _stripeAccountId = accountId;
      _loadingPayoutSetup = false;
    });
  }

  Future<void> _startProviderPayoutSetup() async {
    setState(() => _startingPayoutSetup = true);

    final accountResult =
        await widget.repository.ensureMyStripeConnectAccount();
    if (!mounted) {
      return;
    }
    final accountId = accountResult.accountId;
    if (accountId == null || accountId.isEmpty) {
      setState(() => _startingPayoutSetup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accountResult.errorMessage ?? 'Unable to create payout account.',
          ),
        ),
      );
      return;
    }

    final onboardingResult =
        await widget.repository.createMyStripeOnboardingLink();
    if (!mounted) {
      return;
    }

    setState(() {
      _stripeAccountId = accountId;
      _startingPayoutSetup = false;
    });

    final link = onboardingResult.onboardingUrl;
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onboardingResult.errorMessage ??
                'Unable to generate onboarding link.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri != null) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opened Stripe onboarding in browser.')),
        );
        return;
      }
    }

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open browser. Stripe onboarding link copied.'),
      ),
    );
  }

  Future<void> _loadServicePage() async {
    setState(() => _loadingPage = true);
    try {
      final page = await widget.repository.fetchOrCreateOwnServicePage();
      if (!mounted) {
        return;
      }
      setState(() => _servicePage = page);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load your service page.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingPage = false);
      }
    }
  }

  Future<void> _editServicePage() async {
    final current = _servicePage;
    if (current == null) {
      return;
    }

    final updated = await Navigator.of(context).push<ServicePage>(
      MaterialPageRoute<ServicePage>(
        builder: (_) => ServicePageEditorScreen(
          initialPage: current,
          repository: widget.repository,
        ),
      ),
    );

    if (updated == null) {
      return;
    }

    final saved = await widget.repository.upsertOwnServicePage(updated);
    if (!mounted) {
      return;
    }

    setState(() => _servicePage = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service page updated.')),
    );
  }

  Future<void> _copyServiceLink() async {
    final page = _servicePage;
    if (page == null) {
      return;
    }
    final link = widget.repository.servicePageLink(page);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service page link copied.')),
    );
  }

  void _previewServicePage() {
    final page = _servicePage;
    if (page == null) {
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

  Future<void> _startPaymentMethodSetup() async {
    setState(() => _startingPaymentSetup = true);
    final result = await widget.repository.createStripePaymentSetupLink();
    if (!mounted) {
      return;
    }
    setState(() => _startingPaymentSetup = false);

    final url = result.url;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'Unable to start secure payment setup.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri != null) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        if (!mounted) {
          return;
        }
        if (result.mode == 'mock') {
          setState(() {
            _savedCardBrand = result.cardBrand;
            _savedCardLast4 = result.cardLast4;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mode == 'mock'
                  ? 'Mock Stripe payment method saved.'
                  : 'Opened Stripe secure payment setup. Return here and refresh after completing it.',
            ),
          ),
        );
        await _loadPaymentMethodStatus(showErrors: false);
        return;
      }
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open browser. Stripe setup link copied.'),
      ),
    );
  }

  Future<void> _loadPaymentMethodStatus({bool showErrors = false}) async {
    setState(() => _loadingPaymentMethod = true);
    final result = await widget.repository.fetchStripePaymentMethodStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedCardBrand = result.cardBrand;
      _savedCardLast4 = result.cardLast4;
      _loadingPaymentMethod = false;
    });
    if (showErrors && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage!)),
      );
    }
  }

  String _formatSubscriptionDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  String _formatBookingDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${date.year} at $hour:$minute $period';
  }

  Future<void> _approveGuardianBooking(ServiceBooking booking) async {
    final error = await widget.repository.approveGuardianBooking(booking);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Booking approved. Parent presence confirmed and escrow funded.',
        ),
      ),
    );
  }

  Future<void> _declineGuardianBooking(ServiceBooking booking) async {
    final error = await widget.repository.declineGuardianBooking(booking);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Booking declined.')),
    );
  }

  Future<void> _toggleProviderSubscription() async {
    if (_updatingSubscription) {
      return;
    }
    setState(() => _updatingSubscription = true);
    try {
      if (widget.repository.hasActiveProviderSubscription) {
        await widget.repository.cancelProviderSubscription();
      } else {
        await widget.repository.activateProviderSubscription();
      }
      if (!mounted) {
        return;
      }
      setState(() => _updatingSubscription = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.repository.hasActiveProviderSubscription
                ? 'Giggo Pro activated. You now keep 100% of service earnings.'
                : 'Giggo Pro canceled. Standard 20% platform fee applies.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _updatingSubscription = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Widget _buildProviderSubscriptionCard(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.repository.profileForView;
    final active = user.providerSubscriptionActive;
    final renewsAt = user.providerSubscriptionRenewsAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Giggo Pro',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(
                  label: Text(active ? 'Active' : 'Optional'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$${GigRepository.providerSubscriptionMonthlyPrice.toStringAsFixed(2)}/month',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'You keep 100% of your service earnings. No 20% platform fee is taken while Pro is active.'
                  : 'Subscribe monthly to keep 100% of your service earnings instead of paying the standard 20% platform fee.',
            ),
            if (active && renewsAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Renews ${_formatSubscriptionDate(renewsAt)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: active
                  ? OutlinedButton.icon(
                      onPressed: _updatingSubscription
                          ? null
                          : _toggleProviderSubscription,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(
                        _updatingSubscription
                            ? 'Updating...'
                            : 'Cancel Giggo Pro',
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _updatingSubscription
                          ? null
                          : _toggleProviderSubscription,
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: Text(
                        _updatingSubscription
                            ? 'Starting...'
                            : 'Subscribe for \$19.99/month',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSettingsCard(BuildContext context) {
    final hasSavedCard = _savedCardLast4 != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment settings',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a secure card for faster checkout and service bookings.',
            ),
            const SizedBox(height: 6),
            Text(
              'Stripe collects and stores the full card securely. Giggo never sees or stores your card number or CVV.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (_loadingPaymentMethod) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            if (hasSavedCard) ...[
              Text(
                '${(_savedCardBrand ?? 'Card').toUpperCase()} **** $_savedCardLast4',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _startingPaymentSetup ? null : _startPaymentMethodSetup,
                icon: const Icon(Icons.credit_card_outlined),
                label: Text(
                  _startingPaymentSetup
                      ? 'Opening Stripe...'
                      : hasSavedCard
                          ? 'Update Card with Stripe'
                          : 'Add Card with Stripe',
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingPaymentMethod
                    ? null
                    : () => _loadPaymentMethodStatus(showErrors: true),
                icon: const Icon(Icons.refresh),
                label: Text(
                  _loadingPaymentMethod
                      ? 'Checking Stripe...'
                      : 'Refresh Stripe Card Status',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppThemeCard(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) {
        final systemDark =
            MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final darkEnabled = themeMode == ThemeMode.dark ||
            themeMode == ThemeMode.system && systemDark;

        return Card(
          child: SwitchListTile.adaptive(
            secondary: Icon(
              darkEnabled
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            title: const Text('Dark mode'),
            subtitle: const Text('Apply dark mode across the whole app.'),
            value: darkEnabled,
            onChanged: (enabled) {
              setAppThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
            },
          ),
        );
      },
    );
  }

  Widget _buildGuardianSafetyCard(BuildContext context) {
    final user = widget.repository.profileForView;
    final isMinor = user.requiresGuardianServiceApproval;
    final guardianEmail = user.parentEmail.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMinor ? 'Parent safety link' : 'Parent approvals',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (isMinor) ...[
              Text(
                guardianEmail.isEmpty
                    ? 'Parent approval is required before booking services. Add a parent email during signup or contact support to link one.'
                    : 'Linked parent: $guardianEmail',
              ),
              const SizedBox(height: 8),
              const Text(
                'Your parent must approve every service request and confirm they will be present before escrow is funded.',
              ),
            ] else ...[
              const Text(
                'This is your parent portal. Child service requests linked to your email appear here, and you can still search and book services for yourself from Home.',
              ),
            ],
            const SizedBox(height: 12),
            StreamBuilder<List<ServiceBooking>>(
              stream: widget.repository.watchGuardianPendingBookings(),
              builder: (context, snapshot) {
                final bookings = snapshot.data ?? const <ServiceBooking>[];
                if (bookings.isEmpty) {
                  return Text(
                    isMinor
                        ? 'No pending parent approvals right now.'
                        : 'No child service requests need approval right now.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }

                return Column(
                  children: bookings.map((booking) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.serviceTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Child: ${booking.clientName}'),
                          Text('Provider: ${booking.providerName}'),
                          Text(
                              'When: ${_formatBookingDate(booking.scheduledDate)}'),
                          Text(
                            'Escrow: \$${booking.escrowAmount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Approve only if you will be present with the child during this service.',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () =>
                                    _approveGuardianBooking(booking),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Approve & Confirm Presence'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _declineGuardianBooking(booking),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Decline'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderPayoutCard(BuildContext context) {
    final hasAccount = (_stripeAccountId ?? '').trim().isNotEmpty;
    final shortAccount = hasAccount
        ? '${_stripeAccountId!.substring(0, _stripeAccountId!.length > 12 ? 12 : _stripeAccountId!.length)}...'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider payout setup',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.repository.hasActiveProviderSubscription
                  ? 'Connect your Stripe account to receive 100% of provider earnings from completed bookings.'
                  : 'Connect your Stripe account to receive provider payouts after the standard 20% platform fee.',
            ),
            const SizedBox(height: 10),
            if (_loadingPayoutSetup)
              const LinearProgressIndicator()
            else
              Text(
                hasAccount
                    ? 'Connected account: $shortAccount'
                    : 'No Stripe payout account connected yet.',
                style: TextStyle(
                  color: hasAccount
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _startingPayoutSetup ? null : _startProviderPayoutSetup,
                icon: const Icon(Icons.account_balance_outlined),
                label: Text(
                  _startingPayoutSetup
                      ? 'Starting setup...'
                      : hasAccount
                          ? 'Re-open Stripe onboarding'
                          : 'Connect Stripe payouts',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLegalInfo(LegalInfoType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalInfoScreen(type: type),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will mark your Giggo account and service page as deleted. You may need to sign in again first for security.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || _deletingAccount) {
      return;
    }

    setState(() => _deletingAccount = true);
    final error = await widget.repository.deleteCurrentAccount();
    if (!mounted) {
      return;
    }
    setState(() => _deletingAccount = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    widget.onLoggedOut?.call();
  }

  Future<void> _logout() async {
    await widget.repository.logout();
    if (!mounted) {
      return;
    }
    widget.onLoggedOut?.call();
  }

  Widget _buildLegalAndAccountCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal and account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Review Giggo policies or delete your account from the app.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openLegalInfo(LegalInfoType.privacy),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy Policy'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openLegalInfo(LegalInfoType.terms),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Terms'),
                ),
              ],
            ),
            const Divider(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deletingAccount ? null : _deleteAccount,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  _deletingAccount ? 'Deleting...' : 'Delete account',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.repository.profileForView;
    if (!_isBusinessAccount) {
      return _buildClientView(context, user);
    }

    final myUid = widget.repository.currentUserUid;
    final myGigCount = widget.repository.gigs
        .where((gig) => gig.providerUid != null && gig.providerUid == myUid)
        .length;

    final theme = Theme.of(context);
    final panelColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final shadowColor =
        theme.brightness == Brightness.dark ? Colors.transparent : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            Center(
              child: Text(
                'Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your provider profile',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        child: Text(
                          user.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
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
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.bio,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoPill(
                        label: 'Rating ${user.rating.toStringAsFixed(1)}',
                      ),
                      _InfoPill(
                        label: '${user.completedGigs} completed services',
                      ),
                      _InfoPill(label: 'Age ${user.ageBadge}'),
                      _InfoPill(
                        label: user.backgroundChecked
                            ? 'Background checked'
                            : 'Background check optional',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildAppThemeCard(context),
            const SizedBox(height: 14),
            _buildPaymentSettingsCard(context),
            const SizedBox(height: 14),
            _buildGuardianSafetyCard(context),
            const SizedBox(height: 14),
            _buildProviderSubscriptionCard(context),
            const SizedBox(height: 14),
            _buildProviderPayoutCard(context),
            const SizedBox(height: 14),
            _buildLegalAndAccountCard(context),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store performance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricPill(
                        label: 'Active listings',
                        value: '$myGigCount',
                        icon: Icons.work_outline,
                      ),
                      _MetricPill(
                        label: 'Portfolio photos',
                        value: '${_servicePage?.imageUrls.length ?? 0}',
                        icon: Icons.photo_library_outlined,
                      ),
                      _MetricPill(
                        label: 'Skills shown',
                        value:
                            '${_servicePage?.categories.length ?? user.skills.length}',
                        icon: Icons.grid_view_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () async {
                  await _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildClientView(BuildContext context, UserProfile user) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          centerTitle: true,
          title: Text('Client Profile'),
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
                      Text(
                        'Welcome, ${user.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(user.bio),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Rating ${user.rating.toStringAsFixed(1)}',
                            ),
                          ),
                          Chip(
                              label: Text(
                                  '${user.completedGigs} completed services')),
                          Chip(label: Text('Age ${user.ageBadge}')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildAppThemeCard(context),
              const SizedBox(height: 14),
              _buildPaymentSettingsCard(context),
              const SizedBox(height: 14),
              _buildGuardianSafetyCard(context),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client tools',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text('- Discover trusted local services'),
                      const Text('- Message providers directly in-app'),
                      const Text(
                          '- Use escrow-first checkout for safer payments'),
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
                        'Want to offer services too?',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a new account with the business option enabled to access the provider service-page UI.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildLegalAndAccountCard(context),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$value - $label',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
