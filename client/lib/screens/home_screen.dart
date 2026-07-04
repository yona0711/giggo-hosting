import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/gig.dart';
import '../services/gig_repository.dart';
import 'gig_detail_screen.dart';
import 'post_gig_screen.dart';
import 'service_public_page_screen.dart';

enum HomeMode { findWork, postGig }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final categoryVisuals = const {
    'All': '📍',
    'Pets': '🐶',
    'Auto': '🚗',
    'Home': '🏠',
    'Tutoring': '🎓',
    'Moving': '📦',
    'Cleaning': '🧹',
    'Tech': '💻',
  };

  String selectedCategory = 'All';
  String searchQuery = '';
  bool isLoading = true;
  HomeMode mode = HomeMode.findWork;
  late final TextEditingController _searchController;
  final Map<String, String?> _providerLogoUrls = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadGigs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGigs() async {
    await widget.repository.fetchGigs();
    if (mounted) {
      setState(() => isLoading = false);
      _loadProviderLogos();
    }
  }

  Future<void> _loadProviderLogos() async {
    final providerUids = providerPages
        .map((entry) => entry.featuredGig.providerUid)
        .where((uid) => uid != null && uid.isNotEmpty)
        .cast<String>()
        .toSet();

    final missingUids = providerUids
        .where((uid) => !_providerLogoUrls.containsKey(uid))
        .toList();

    for (final uid in missingUids) {
      final page = await widget.repository.fetchServicePageByOwnerUid(uid);
      if (!mounted) {
        return;
      }
      final imageUrl =
          (page?.logoUrl.isNotEmpty == true) ? page!.logoUrl : null;
      if (mounted) {
        setState(() {
          _providerLogoUrls[uid] = imageUrl;
        });
      }
    }
  }

  List<Gig> get visibleGigs {
    final byCategory = widget.repository.gigsByCategory(selectedCategory);
    if (searchQuery.trim().isEmpty) {
      return byCategory;
    }
    final query = searchQuery.trim().toLowerCase();
    final matches = byCategory
        .map((gig) => (gig: gig, score: _searchScore(gig, query)))
        .where((match) => match.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return matches.map((match) => match.gig).toList();
  }

  int _searchScore(Gig gig, String query) {
    var score = 0;
    final title = gig.title.toLowerCase();
    final category = gig.category.toLowerCase();
    final provider = gig.providerName.toLowerCase();
    final location = gig.location.toLowerCase();
    final description = gig.description.toLowerCase();
    final tags = gig.tags.map((tag) => tag.toLowerCase()).toList();

    if (tags.any((tag) => tag == query)) score += 120;
    if (title == query) score += 100;
    if (category == query) score += 80;
    if (tags.any((tag) => tag.contains(query))) score += 70;
    if (title.contains(query)) score += 55;
    if (category.contains(query)) score += 40;
    if (provider.contains(query)) score += 30;
    if (location.contains(query)) score += 25;
    if (description.contains(query)) score += 15;
    return score;
  }

  List<String> get topProviders {
    final counts = <String, int>{};
    for (final gig in widget.repository.gigs.where((gig) => gig.isActive)) {
      counts[gig.providerName] = (counts[gig.providerName] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((entry) => entry.key).toList();
  }

  List<_ProviderSummary> get providerPages {
    final grouped = <String, List<Gig>>{};
    for (final gig in visibleGigs) {
      grouped.putIfAbsent(gig.providerName, () => <Gig>[]).add(gig);
    }
    final summaries = grouped.entries.map((entry) {
      final listings = entry.value;
      listings.sort((a, b) => a.price.compareTo(b.price));
      final featuredGig = listings.first;
      return _ProviderSummary(
        providerName: entry.key,
        location: featuredGig.location,
        listingCount: listings.length,
        startingPrice: featuredGig.price,
        featuredGig: featuredGig,
      );
    }).toList()
      ..sort((a, b) => b.listingCount.compareTo(a.listingCount));
    return summaries;
  }

  List<_ProviderSummary> get topProviderPages {
    return providerPages.take(5).toList();
  }

  Future<void> _openProviderPage(
      BuildContext context, _ProviderSummary provider) async {
    await _openLiveProviderStore(
      context: context,
      repository: widget.repository,
      gig: provider.featuredGig,
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerPagesToShow = providerPages.take(12).toList();
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'giggo',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                child: Text(
                  'top gigs in the area',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 88,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categoryVisuals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final category = categoryVisuals.keys.elementAt(index);
                  final emoji = categoryVisuals.values.elementAt(index);
                  final selected = selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedCategory = category);
                      _loadProviderLogos();
                    },
                    child: Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.cardTheme.color ??
                                theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final provider = index < providerPagesToShow.length
                        ? providerPagesToShow[index]
                        : null;
                    return GestureDetector(
                      onTap: provider == null
                          ? null
                          : () => _openProviderPage(context, provider),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: provider == null
                            ? null
                            : Center(
                                child: Text(
                                  provider.providerName.isNotEmpty
                                      ? provider.providerName[0].toUpperCase()
                                      : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindWorkSection extends StatelessWidget {
  const _FindWorkSection({
    super.key,
    required this.isLoading,
    required this.gigs,
    required this.repository,
  });

  final bool isLoading;
  final List<Gig> gigs;
  final GigRepository repository;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (gigs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
              'No service listings in this category yet. Try another category.'),
        ),
      );
    }

    return Column(
      children: gigs.map((gig) {
        final canWork = repository.canCurrentUserWorkGig(gig);
        final reason = repository.restrictedReason(gig);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              title: Text(
                gig.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${gig.category} • ${gig.providerName} • ${gig.location}'),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to view details and contact provider',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reason != null)
                      Text(
                        reason,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '\$${gig.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    canWork ? Icons.verified : Icons.block,
                    size: 18,
                    color: canWork
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
              onTap: () async {
                await _openLiveProviderStore(
                  context: context,
                  repository: repository,
                  gig: gig,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ClientDiscoverySection extends StatelessWidget {
  const _ClientDiscoverySection({
    super.key,
    required this.isLoading,
    required this.gigs,
    required this.repository,
  });

  final bool isLoading;
  final List<Gig> gigs;
  final GigRepository repository;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (gigs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No services found. Try another category or a broader search.',
          ),
        ),
      );
    }

    final grouped = <String, List<Gig>>{};
    for (final gig in gigs) {
      grouped.putIfAbsent(gig.providerName, () => <Gig>[]).add(gig);
    }

    final storeSummaries = grouped.entries.map((entry) {
      final listings = entry.value;
      listings.sort((a, b) => a.price.compareTo(b.price));
      final featured = listings.first;
      return _ProviderSummary(
        providerName: entry.key,
        location: featured.location,
        listingCount: listings.length,
        startingPrice: featured.price,
        featuredGig: featured,
      );
    }).toList()
      ..sort((a, b) => b.listingCount.compareTo(a.listingCount));

    final topStores = storeSummaries.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Popular businesses',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: topStores.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final store = topStores[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await _openLiveProviderStore(
                            context: context,
                            repository: repository,
                            gig: store.featuredGig,
                          );
                        },
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront_outlined,
                                      size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      store.providerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${store.listingCount} listings • ${store.location}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              Text(
                                'From \$${store.startingPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...gigs.map((gig) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gig.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                          ),
                          child: Text(
                            '\$${gig.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${gig.providerName} • ${gig.location}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(gig.category)),
                        ...gig.tags.take(3).map(
                              (tag) => Chip(
                                avatar:
                                    const Icon(Icons.sell_outlined, size: 16),
                                label: Text(tag),
                              ),
                            ),
                        const Chip(label: Text('Family-safe chat')),
                        const Chip(label: Text('Escrow available')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GigDetailScreen(
                                gig: gig,
                                repository: repository,
                              ),
                            ),
                          );
                        },
                        child: const Text('View service details'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

Future<void> _openLiveProviderStore({
  required BuildContext context,
  required GigRepository repository,
  required Gig gig,
}) async {
  final providerUid = gig.providerUid;
  if (providerUid == null || providerUid.isEmpty) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GigDetailScreen(gig: gig, repository: repository),
      ),
    );
    return;
  }

  try {
    final page = await repository.fetchOrCreateServicePageForGig(gig);
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServicePublicPageScreen(
          repository: repository,
          shareSlug: page.shareSlug,
          previewPage: page,
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GigDetailScreen(gig: gig, repository: repository),
      ),
    );
  }
}

ImageProvider? _imageProviderForLogo(String? logoUrl) {
  if (logoUrl == null || logoUrl.trim().isEmpty) {
    return null;
  }
  final trimmed = logoUrl.trim();
  if (trimmed.startsWith('data:image/')) {
    try {
      final bytes = base64Decode(trimmed.split(',').last);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(trimmed);
}

class _ProviderSummary {
  const _ProviderSummary({
    required this.providerName,
    required this.location,
    required this.listingCount,
    required this.startingPrice,
    required this.featuredGig,
  });

  final String providerName;
  final String location;
  final int listingCount;
  final double startingPrice;
  final Gig featuredGig;
}

class _PostGigSection extends StatelessWidget {
  const _PostGigSection({
    super.key,
    required this.repository,
    required this.onPosted,
  });

  final GigRepository repository;
  final VoidCallback onPosted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post a local service',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customer posts a service listing → worker accepts → customer pays upfront → escrow releases after completion.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final gig = await Navigator.of(context).push<Gig>(
                  MaterialPageRoute(
                    builder: (_) => PostGigScreen(repository: repository),
                  ),
                );
                if (gig != null) {
                  await repository.addGig(gig);
                  onPosted();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Service Listing'),
            ),
          ],
        ),
      ),
    );
  }
}
