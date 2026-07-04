import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gig.dart';
import '../models/service_booking.dart';
import '../models/service_conversation.dart';
import '../models/service_page.dart';
import '../services/gig_repository.dart';
import 'post_gig_screen.dart';
import 'service_conversation_screen.dart';
import 'service_page_editor_screen.dart';
import 'service_public_page_screen.dart';

class ServicePageTabScreen extends StatefulWidget {
  const ServicePageTabScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  State<ServicePageTabScreen> createState() => _ServicePageTabScreenState();
}

class _ServicePageTabScreenState extends State<ServicePageTabScreen> {
  ServicePage? _servicePage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await widget.repository.fetchGigs();
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
        const SnackBar(
            content: Text('Using local service page draft until sync works.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _editPage() async {
    final page = _servicePage;
    if (page == null) {
      return;
    }

    final updated = await Navigator.of(context).push<ServicePage>(
      MaterialPageRoute<ServicePage>(
        builder: (_) => ServicePageEditorScreen(
          initialPage: page,
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

  String _formatDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$m/$d/${value.year}';
  }

  String _reminderLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Tomorrow';
    }
    return 'Upcoming';
  }

  Future<void> _postServiceListing() async {
    final draft = await Navigator.of(context).push<Gig>(
      MaterialPageRoute<Gig>(
        builder: (_) => PostGigScreen(repository: widget.repository),
      ),
    );

    if (draft == null) {
      return;
    }

    await widget.repository.addGig(draft);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service listing posted.')),
    );
    setState(() {});
  }

  Future<void> _deleteGig(Gig gig) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete service?'),
          content: const Text(
            'This will remove the service from your listings. Do you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.repository.deleteGig(gig.id);
      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service listing deleted.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete service listing.')),
      );
    }
  }

  Future<void> _toggleGigStatus(Gig gig) async {
    final updated = gig.copyWith(isActive: !gig.isActive);
    await widget.repository.updateGig(updated);
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isActive
              ? 'Service listing is active.'
              : 'Service listing paused.',
        ),
      ),
    );
  }

  Future<void> _copyShareLink() async {
    final page = _servicePage;
    if (page == null) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(text: widget.repository.servicePageLink(page)),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service page link copied.')),
    );
  }

  void _previewPublicPage() {
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

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.repository.profileForView.isBusinessAccount;
    if (!isBusiness) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Service page tools are available for business accounts.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final page = _servicePage;
    if (page == null) {
      return const Center(child: Text('Unable to load service page.'));
    }

    final myUid = widget.repository.currentUserUid;
    final myListings = widget.repository.gigs
        .where((gig) => gig.providerUid != null && gig.providerUid == myUid)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  'Edit Service Page',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _ActionChip(
                    label: 'Post',
                    onTap: _postServiceListing,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                  ),
                  _ActionChip(
                    label: 'Edit page',
                    onTap: _editPage,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                  ),
                  _ActionChip(
                    label: 'Share Link',
                    onTap: _copyShareLink,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                  ),
                  _ActionChip(
                    label: 'Preview',
                    onTap: _previewPublicPage,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Text(
                  'Booking Reminders Tab',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Service Listings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 18),
                    if (myListings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'No listings yet. Post a service to get started.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                        ),
                      )
                    else
                      Column(
                        children: myListings.take(6).map((gig) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          gig.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '\$${gig.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Chip(
                                              label: Text(
                                                gig.isActive
                                                    ? 'Active'
                                                    : 'Paused',
                                              ),
                                              backgroundColor: gig.isActive
                                                  ? const Color(0xFFE9FBEF)
                                                  : const Color(0xFFFFF3D6),
                                              labelStyle: TextStyle(
                                                color: gig.isActive
                                                    ? const Color(0xFF147A35)
                                                    : const Color(0xFF8A5A00),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            ...gig.tags.take(3).map(
                                                  (tag) => Chip(
                                                    label: Text(tag),
                                                    avatar: const Icon(
                                                      Icons.sell_outlined,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _MiniButton(
                                    label: 'Edit',
                                    backgroundColor: const Color(0xFF36D952),
                                    onTap: () async {
                                      final updated =
                                          await Navigator.of(context).push<Gig>(
                                        MaterialPageRoute<Gig>(
                                          builder: (_) => PostGigScreen(
                                            repository: widget.repository,
                                            initialGig: gig,
                                          ),
                                        ),
                                      );
                                      if (updated != null) {
                                        await widget.repository
                                            .updateGig(updated);
                                      }
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniButton(
                                    label: gig.isActive ? 'Pause' : 'Resume',
                                    backgroundColor: gig.isActive
                                        ? const Color(0xFFFFA726)
                                        : const Color(0xFF0A84FF),
                                    onTap: () async {
                                      await _toggleGigStatus(gig);
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniButton(
                                    label: 'Delete',
                                    backgroundColor: const Color(0xFFEF2B2B),
                                    onTap: () async {
                                      await _deleteGig(gig);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
