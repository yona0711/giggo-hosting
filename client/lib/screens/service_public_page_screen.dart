import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gig.dart';
import '../models/service_booking.dart';
import '../models/service_page.dart';
import '../services/gig_repository.dart';
import 'gig_detail_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'service_page_tab_screen.dart';
import 'escrow_screen.dart';
import 'profile_screen.dart';

class ServicePublicPageScreen extends StatefulWidget {
  const ServicePublicPageScreen({
    super.key,
    required this.repository,
    required this.shareSlug,
    this.previewPage,
    this.showNavigationBar = false,
  });

  final GigRepository repository;
  final String shareSlug;
  final ServicePage? previewPage;
  final bool showNavigationBar;

  @override
  State<ServicePublicPageScreen> createState() =>
      _ServicePublicPageScreenState();
}

class _ServicePublicPageScreenState extends State<ServicePublicPageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _bookingNotesController = TextEditingController();
  final TextEditingController _bookingAddressController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSending = false;
  bool _isBooking = false;
  bool _checkingProviderBlock = true;
  bool _providerBlocked = false;
  ServicePage? _servicePage;
  List<Gig> _providerGigs = const <Gig>[];
  String _searchQuery = '';
  String _selectedCategory = 'All Items';
  int _selectedNavIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _servicePage = widget.previewPage;
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bookingNotesController.dispose();
    _bookingAddressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$m/$d/${value.year}';
  }

  String _formatSlot(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '${_formatDate(value)} $hh:$mm';
  }

  String _slotKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y$m$d$h$mm';
  }

  bool _sameSlot(DateTime a, DateTime b) {
    return a.isAtSameMomentAs(b);
  }

  String _heroTitle(ServicePage page) {
    final custom = page.heroHeadline.trim();
    return custom.isEmpty ? page.title : custom;
  }

  String _startingPriceText() {
    if (_providerGigs.isEmpty) {
      return 'Quote';
    }

    final prices = _providerGigs.map((gig) => gig.price).toList()..sort();
    return '\$${prices.first.toStringAsFixed(0)}+';
  }

  String _nextOpenSlotText() {
    final now = DateTime.now();
    final slots = _providerGigs
        .expand((gig) => gig.availableSlots)
        .where((slot) => !slot.isBefore(now))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (slots.isEmpty) {
      return 'Message';
    }

    return _formatDate(slots.first);
  }

  Future<void> _loadProviderBlockState(ServicePage page) async {
    final blocked = await widget.repository.isUserBlocked(page.ownerUid);
    if (!mounted) {
      return;
    }
    setState(() {
      _providerBlocked = blocked;
      _checkingProviderBlock = false;
    });
  }

  Future<void> _toggleProviderBlock(ServicePage page) async {
    try {
      if (_providerBlocked) {
        await widget.repository.unblockUser(page.ownerUid);
      } else {
        await widget.repository.blockUser(
          userUid: page.ownerUid,
          userName: page.ownerName,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _providerBlocked = !_providerBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _providerBlocked
                ? 'Blocked ${page.ownerName}.'
                : 'Unblocked ${page.ownerName}.',
          ),
        ),
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

  Future<void> _reportProviderStore(ServicePage page) async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report provider store'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Spam, unsafe service, misleading listing...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Add anything the review team should know.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      reasonController.dispose();
      detailsController.dispose();
      return;
    }

    try {
      await widget.repository.reportContent(
        contentType: 'servicePage',
        targetId: page.shareSlug,
        targetOwnerUid: page.ownerUid,
        targetOwnerName: page.ownerName,
        reason: reasonController.text,
        details: detailsController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      reasonController.dispose();
      detailsController.dispose();
    }
  }

  FontWeight _headlineWeight(String storefrontStyle) {
    if (storefrontStyle == 'bold') {
      return FontWeight.w900;
    }
    if (storefrontStyle == 'minimal') {
      return FontWeight.w600;
    }
    return FontWeight.w800;
  }

  Widget _buildLogoNamePlaceholder(ServicePage page) {
    final label = page.title.trim().isNotEmpty
        ? page.title.trim()
        : page.ownerName.trim().isNotEmpty
            ? page.ownerName.trim()
            : 'Store';

    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFF1F3F5),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
      ),
    );
  }

  Widget _buildHeroSection(ServicePage page) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 680;
            final logo = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: page.logoUrl.trim().isNotEmpty
                  ? Image.network(
                      page.logoUrl,
                      width: isWide ? 132 : 88,
                      height: isWide ? 132 : 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: isWide ? 132 : 88,
                        height: isWide ? 132 : 88,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.12),
                        alignment: Alignment.center,
                        child: const Icon(Icons.storefront_outlined, size: 42),
                      ),
                    )
                  : Container(
                      width: isWide ? 132 : 88,
                      height: isWide ? 132 : 88,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      alignment: Alignment.center,
                      child: const Icon(Icons.storefront_outlined, size: 42),
                    ),
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.verified_user_outlined,
                      label: 'Giggo provider',
                    ),
                    if (page.city.trim().isNotEmpty)
                      _InfoPill(
                        icon: Icons.place_outlined,
                        label: page.city,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _heroTitle(page),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: _headlineWeight(page.storefrontStyle),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  page.ownerName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(page.about),
                if (page.announcement.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.campaign_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(page.announcement)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ProviderStat(
                      value: _providerGigs.length.toString(),
                      label: 'Services',
                    ),
                    _ProviderStat(
                      value: _startingPriceText(),
                      label: 'Starting at',
                    ),
                    _ProviderStat(
                      value: _nextOpenSlotText(),
                      label: 'Next slot',
                    ),
                  ],
                ),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  logo,
                  const SizedBox(width: 22),
                  Expanded(child: details),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logo,
                const SizedBox(height: 16),
                details,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryPills(ServicePage page) {
    final labels = <String>[
      'All Items',
      ...page.categories.where((c) =>
          c.trim().isNotEmpty && c.trim().toLowerCase() != 'getting started')
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.map((label) {
          final selected = label == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedCategory = label);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBoutiqueHeader(ServicePage page) {
    final brandColor = _servicePageBrandColor(page);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF111111);
    final secondaryText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF7B8794);
    final fieldFill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldBorder =
        isDark ? const Color(0xFF333333) : const Color(0xFFE7EBEF);
    final filterFill = isDark ? Colors.white : brandColor;
    final filterIcon = isDark ? const Color(0xFF111111) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7EBEF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: page.logoUrl.trim().isNotEmpty
                    ? Image.network(
                        page.logoUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildLogoNamePlaceholder(page),
                      )
                    : _buildLogoNamePlaceholder(page),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, Welcome',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7B8794),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      page.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Store safety options',
                iconColor: const Color(0xFF111111),
                onSelected: (value) {
                  if (value == 'report') {
                    _reportProviderStore(page);
                  }
                  if (value == 'block') {
                    _toggleProviderBlock(page);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: Text('Report store'),
                  ),
                  PopupMenuItem(
                    value: 'block',
                    enabled: !_checkingProviderBlock,
                    child: Text(
                      _providerBlocked ? 'Unblock provider' : 'Block provider',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  style: Theme.of(context).textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: TextStyle(color: secondaryText),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: secondaryText,
                    ),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: brandColor),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 42,
              height: 42,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: filterFill,
                  foregroundColor: filterIcon,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  setState(() => _selectedCategory = 'All Items');
                },
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'Reset filters',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildBoutiqueCategoryPills(page),
      ],
    );
  }

  Widget _buildBoutiqueCategoryPills(ServicePage page) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBorder =
        isDark ? Colors.white : Theme.of(context).colorScheme.primary;
    final borderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFD9E2EC);
    final labels = <String>[
      'All Items',
      ...page.categories.where((c) =>
          c.trim().isNotEmpty && c.trim().toLowerCase() != 'getting started')
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final selected = label == _selectedCategory;
          return ChoiceChip(
            label: Text(label),
            avatar: Icon(
              index == 0
                  ? Icons.grid_view_rounded
                  : Icons.home_repair_service_outlined,
              size: 13,
              color: const Color(0xFF111111),
            ),
            selected: selected,
            showCheckmark: false,
            labelStyle: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            selectedColor: Colors.white,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? selectedBorder : borderColor,
              width: selected ? 1.4 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            onSelected: (_) => setState(() => _selectedCategory = label),
          );
        },
      ),
    );
  }

  List<Gig> _filteredGigs(ServicePage page) {
    final query = _searchQuery.toLowerCase();
    final matches = _providerGigs
        .where((gig) => gig.isActive)
        .map((gig) {
          final categoryMatches = _selectedCategory == 'All Items' ||
              gig.category.toLowerCase() == _selectedCategory.toLowerCase();
          final score = query.isEmpty ? 1 : _searchScore(gig, query);
          return (gig: gig, score: categoryMatches ? score : 0);
        })
        .where((match) => match.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return matches.map((match) => match.gig).toList();
  }

  int _searchScore(Gig gig, String query) {
    var score = 0;
    final title = gig.title.toLowerCase();
    final category = gig.category.toLowerCase();
    final description = gig.description.toLowerCase();
    final tags = gig.tags.map((tag) => tag.toLowerCase()).toList();

    if (tags.any((tag) => tag == query)) score += 120;
    if (title == query) score += 100;
    if (category == query) score += 80;
    if (tags.any((tag) => tag.contains(query))) score += 70;
    if (title.contains(query)) score += 55;
    if (category.contains(query)) score += 40;
    if (description.contains(query)) score += 15;
    return score;
  }

  String _imageUrlForGig(ServicePage page, Gig gig, int index) {
    if (gig.imageUrls.isNotEmpty) {
      return gig.imageUrls.first;
    }
    if (page.imageUrls.isNotEmpty) {
      return page.imageUrls[index % page.imageUrls.length];
    }
    return '';
  }

  Widget _buildBoutiqueListings(ServicePage page) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF111111);
    final secondaryText =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF7B8794);
    final panelFill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFE7EBEF);
    final visibleGigs = _filteredGigs(page);
    if (visibleGigs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: panelFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          'No matching services found.',
          textAlign: TextAlign.center,
          style: TextStyle(color: primaryText),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.56,
      ),
      itemCount: visibleGigs.length,
      itemBuilder: (context, index) {
        final gig = visibleGigs[index];
        final imageUrl = _imageUrlForGig(page, gig, index);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GigDetailScreen(
                  gig: gig,
                  repository: widget.repository,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: panelFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildServiceImageFallback(),
                              )
                            : _buildServiceImageFallback(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.58)
                                : Colors.white.withOpacity(0.86),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_border,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  gig.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  gig.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (gig.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 24,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gig.tags.take(4).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (context, tagIndex) {
                        final tag = gig.tags[tagIndex];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '\$${gig.price.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '5.0',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceImageFallback() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8EEF3),
      ),
      child: Icon(
        Icons.home_repair_service_outlined,
        size: 34,
        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280),
      ),
    );
  }

  Widget _buildSearchHeader(ServicePage page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Hello, Welcome 👋',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onBackground
                              .withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    page.ownerName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              child: page.logoUrl.trim().isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        page.logoUrl,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 30,
                        ),
                      ),
                    )
                  : const Icon(Icons.person, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search services…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {},
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
        ),
        const SizedBox(height: 14),
        _buildCategoryPills(page),
        const SizedBox(height: 12),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message this provider',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Hi! I would like to book your service...',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSending ||
                            _providerBlocked ||
                            _messageController.text.trim().isEmpty
                        ? null
                        : _sendMessage,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_isSending ? 'Sending...' : 'Message Provider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceListings(ServicePage page) {
    final visibleGigs = _filteredGigs(page);
    if (visibleGigs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('No matching services found.'),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.69,
      ),
      itemCount: visibleGigs.length,
      itemBuilder: (context, index) {
        final gig = visibleGigs[index];
        final imageUrl = page.imageUrls.isNotEmpty
            ? page.imageUrls[index % page.imageUrls.length]
            : '';
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GigDetailScreen(
                  gig: gig,
                  repository: widget.repository,
                ),
              ),
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 140,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            )
                          : Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.12),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.home_repair_service_outlined,
                                size: 40,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gig.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        gig.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '\$${gig.price.toStringAsFixed(0)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '5.0',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategories(ServicePage page) {
    if (page.categories.isEmpty) {
      return const Text('No categories specified yet.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: page.categories
          .map(
            (category) => Chip(
              label: Text(category),
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTrustHighlights() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Text(
                  'Family-safe provider signals',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('• All chats stay in-app with moderation tools'),
            const Text('• Escrow flow available for safer payments'),
            const Text('• Clear service terms help avoid surprises'),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTrustCard() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Provider trust signals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _TrustRow(
              icon: Icons.chat_bubble_outline,
              text: 'Messages stay in Giggo with moderation tools.',
            ),
            const _TrustRow(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Escrow booking is available for safer payments.',
            ),
            const _TrustRow(
              icon: Icons.assignment_turned_in_outlined,
              text: 'Service details and availability are visible up front.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookSlot(List<DateTime> availableSlots) async {
    final page = _servicePage;
    if (page == null || _isBooking || availableSlots.isEmpty) {
      return;
    }

    DateTime selectedSlot = availableSlots.first;
    _bookingNotesController.clear();
    _bookingAddressController.clear();
    String? addressError;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Booking details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.repository.profileForView
                      .requiresGuardianServiceApproval) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Parent approval is required before this service is confirmed or paid. Your parent must log in and confirm they will be present.',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  DropdownButtonFormField<DateTime>(
                    value: selectedSlot,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Available date & time',
                    ),
                    items: availableSlots
                        .map(
                          (slot) => DropdownMenuItem<DateTime>(
                            value: slot,
                            child: Text(_formatSlot(slot)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedSlot = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bookingAddressController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Service address',
                      hintText: '123 Main St, Apt 4, City',
                      errorText: addressError,
                    ),
                    onChanged: (_) {
                      if (addressError != null) {
                        setDialogState(() => addressError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bookingNotesController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Optional: add notes for this booked slot',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final address = _bookingAddressController.text.trim();
                    if (address.isEmpty) {
                      setDialogState(
                        () => addressError = 'Address is required',
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Confirm Booking'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldProceed != true || !mounted) {
      return;
    }

    Gig? selectedGig;
    for (final gig in _providerGigs) {
      final hasSlot =
          gig.availableSlots.any((slot) => _sameSlot(slot, selectedSlot));
      if (hasSlot) {
        selectedGig = gig;
        break;
      }
    }

    final serviceTitle = selectedGig?.title ?? page.title;
    final double escrowAmount = (selectedGig != null
            ? selectedGig.price
            : (_providerGigs.isNotEmpty ? _providerGigs.first.price : 0))
        .toDouble();

    if (escrowAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to process escrow payment for this booking.'),
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    final error = await widget.repository.bookServiceDate(
      providerUid: page.ownerUid,
      providerName: page.ownerName,
      serviceTitle: serviceTitle,
      date: selectedSlot,
      customerAddress: _bookingAddressController.text,
      escrowAmount: escrowAmount,
      providerSubscriptionActive: page.providerSubscriptionActive,
      notes: _bookingNotesController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isBooking = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.repository.profileForView.requiresGuardianServiceApproval
              ? 'Request sent for ${_formatSlot(selectedSlot)}. Parent approval is required before escrow is funded.'
              : 'Booked for ${_formatSlot(selectedSlot)}. Escrow funded: \$${escrowAmount.toStringAsFixed(2)}.',
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final page =
          await widget.repository.fetchServicePageBySlug(widget.shareSlug);
      if (!mounted) {
        return;
      }

      final resolvedPage = page ?? widget.previewPage;
      if (resolvedPage == null) {
        setState(() => _error = 'Service page not found.');
        return;
      }

      final providerGigs =
          await widget.repository.fetchGigsByProviderUid(resolvedPage.ownerUid);

      if (!mounted) {
        return;
      }

      setState(() {
        _servicePage = resolvedPage;
        _providerGigs = providerGigs;
        _error = null;
      });
      await _loadProviderBlockState(resolvedPage);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final fallback = widget.previewPage;
      if (fallback != null) {
        final providerGigs =
            await widget.repository.fetchGigsByProviderUid(fallback.ownerUid);
        if (!mounted) {
          return;
        }
        setState(() {
          _servicePage = fallback;
          _providerGigs = providerGigs;
          _error = null;
        });
        await _loadProviderBlockState(fallback);
        return;
      }

      setState(() => _error = 'Unable to load service page preview.');
    }
  }

  Widget _buildServiceFinder(ServicePage page) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find the right service',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search ${page.ownerName} services, filter by category, or send a booking question.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search services...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.06),
              ),
            ),
            const SizedBox(height: 14),
            _buildCategoryPills(page),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD9E2EC)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact ${page.ownerName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Ask a question or share what you need done...',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSending ||
                              _providerBlocked ||
                              _messageController.text.trim().isEmpty
                          ? null
                          : _sendMessage,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        _isSending ? 'Sending...' : 'Message Provider',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingPanel(ServicePage page) {
    return StreamBuilder<List<ServiceBooking>>(
      stream: widget.repository.watchProviderBookings(page.ownerUid),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? const <ServiceBooking>[];
        final now = DateTime.now();
        final allSlots = _providerGigs
            .expand((gig) => gig.availableSlots)
            .where((slot) => !slot.isBefore(now))
            .toList()
          ..sort((a, b) => a.compareTo(b));
        final bookedKeys =
            bookings.map((b) => _slotKey(b.scheduledDate)).toSet();
        final availableSlots = allSlots
            .where((slot) => !bookedKeys.contains(_slotKey(slot)))
            .toList();
        final unavailableSlots = allSlots
            .where((slot) => bookedKeys.contains(_slotKey(slot)))
            .toList();

        return Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Book ${page.ownerName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose from provider-set available slots. Booked slots are blocked instantly.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _isBooking || _providerBlocked || availableSlots.isEmpty
                            ? null
                            : () => _bookSlot(availableSlots),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      _isBooking ? 'Booking...' : 'Book a Time Slot',
                    ),
                  ),
                ),
                if (availableSlots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'No open slots right now. Message the provider for new availability.',
                    ),
                  ),
                if (availableSlots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Open slots',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSlots
                        .take(12)
                        .map(
                          (slot) => Chip(
                            avatar: const Icon(
                              Icons.event_available_outlined,
                              size: 16,
                            ),
                            label: Text(_formatSlot(slot)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (unavailableSlots.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Unavailable slots',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: unavailableSlots
                        .take(12)
                        .map(
                          (slot) => Chip(
                            avatar: const Icon(
                              Icons.event_busy_outlined,
                              size: 16,
                            ),
                            label: Text(_formatSlot(slot)),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsSection(ServicePage page) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reviews',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('serviceReviews')
                  .where('providerUid', isEqualTo: page.ownerUid)
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No reviews yet.'),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final author = (data['authorName'] as String?) ?? 'User';
                    final text = (data['text'] as String?) ?? '';
                    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            child: Text(author.isNotEmpty
                                ? author[0].toUpperCase()
                                : '?'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(author,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(rating.toStringAsFixed(1),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ),
                                if (text.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(text,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ],
                            ),
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

  Future<void> _sendMessage() async {
    final page = _servicePage;
    if (page == null) {
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (_providerBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unblock ${page.ownerName} before sending a message.'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await widget.repository.sendMessageToProvider(
        providerUid: page.ownerUid,
        providerName: page.ownerName,
        text: text,
      );
      if (!mounted) {
        return;
      }
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent to provider.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _servicePage;
    final pageBackground = _servicePageBrandColor(page);

    return Scaffold(
      backgroundColor: pageBackground,
      bottomNavigationBar:
          widget.showNavigationBar ? _buildNavigationBar() : null,
      body: _error != null
          ? Center(child: Text(_error!))
          : page == null
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    color: pageBackground,
                    image: _buildBackgroundImage(page.backgroundImage),
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      MediaQuery.of(context).padding.top + 12,
                      14,
                      18,
                    ),
                    children: [
                      if (_providerBlocked) ...[
                        MaterialBanner(
                          content: Text(
                            'You blocked ${page.ownerName}. Unblock this provider to message or book.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => _toggleProviderBlock(page),
                              child: const Text('Unblock'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildBoutiqueHeader(page),
                      const SizedBox(height: 18),
                      _buildBoutiqueListings(page),
                      const SizedBox(height: 22),
                      _buildServiceFinder(page),
                      const SizedBox(height: 14),
                      if (page.showTrustHighlights) ...[
                        _buildProviderTrustCard(),
                        const SizedBox(height: 14),
                      ],
                      _buildBookingPanel(page),
                      const SizedBox(height: 14),
                      _buildReviewsSection(page),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNavigationBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBackground =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final navSelected = theme.colorScheme.primary;
    final navUnselected = isDark ? Colors.white70 : const Color(0xFF486581);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: navSelected.withValues(alpha: isDark ? 0.18 : 0.10),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? navSelected : navUnselected,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? navSelected : navUnselected,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) async {
          setState(() => _selectedNavIndex = index);
          await _onNavSelected(index);
        },
        destinations: widget.repository.profileForView.isBusinessAccount
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  label: 'Service Page',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'Payments',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  label: 'Messages',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }

  Color? _parseHexColor(String? colorText) {
    if (colorText == null || colorText.trim().isEmpty) {
      return null;
    }
    final normalized = colorText.trim().toLowerCase();
    final namedColors = <String, Color>{
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'teal': Colors.teal,
      'cyan': Colors.cyan,
    };
    if (namedColors.containsKey(normalized)) {
      return namedColors[normalized];
    }
    final hex = normalized.replaceAll('#', '');
    if (hex.length == 6 || hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        return Color(hex.length == 6 ? 0xFF000000 | value : value);
      }
    }
    return null;
  }

  Color? _customPageBackground(ServicePage? page) {
    final colorText = page?.backgroundColor.trim();
    if (colorText == null || colorText.isEmpty) {
      return null;
    }

    final normalized = colorText.toLowerCase();
    if (normalized == '#ffffff' ||
        normalized == 'ffffff' ||
        normalized == '#ffffffff' ||
        normalized == 'ffffffff') {
      return null;
    }

    return _parseHexColor(colorText);
  }

  Color _servicePageBrandColor(ServicePage? page) {
    return _customPageBackground(page) ?? Theme.of(context).colorScheme.primary;
  }

  Future<void> _onNavSelected(int index) async {
    final isBusiness = widget.repository.profileForView.isBusinessAccount;

    // Map indices to screens for business vs non-business accounts
    if (isBusiness) {
      switch (index) {
        case 0:
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HomeScreen(repository: widget.repository),
          ));
          break;
        case 1:
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => InboxScreen(repository: widget.repository),
          ));
          break;
        case 2:
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ServicePageTabScreen(repository: widget.repository),
          ));
          break;
        case 3:
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EscrowScreen(repository: widget.repository),
          ));
          break;
        case 4:
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProfileScreen(repository: widget.repository),
          ));
          break;
      }
      return;
    }

    // Non-business mapping
    switch (index) {
      case 0:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HomeScreen(repository: widget.repository),
        ));
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InboxScreen(repository: widget.repository),
        ));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(repository: widget.repository),
        ));
        break;
    }
  }

  DecorationImage? _buildBackgroundImage(String backgroundImage) {
    final trimmed = backgroundImage.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      if (trimmed.startsWith('data:image/')) {
        final base64Data = trimmed.split(',').last;
        final bytes = base64Decode(base64Data);
        return DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
        );
      }
      return DecorationImage(
        image: NetworkImage(trimmed),
        fit: BoxFit.cover,
      );
    } catch (_) {
      return null;
    }
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ProviderStat extends StatelessWidget {
  const _ProviderStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
