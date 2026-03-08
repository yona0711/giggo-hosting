import 'package:flutter/material.dart';

import '../models/gig.dart';
import '../services/gig_repository.dart';
import 'gig_detail_screen.dart';
import 'post_gig_screen.dart';

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
  bool isLoading = true;
  HomeMode mode = HomeMode.findWork;

  @override
  void initState() {
    super.initState();
    _loadGigs();
  }

  Future<void> _loadGigs() async {
    await widget.repository.fetchGigs();
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  List<Gig> get visibleGigs {
    return widget.repository.gigsByCategory(selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giggo')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGigs,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.95),
                        Theme.of(context)
                            .colorScheme
                            .secondary
                            .withValues(alpha: 0.95),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giggo – Local gigs for everyone 13+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 138,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map_outlined,
                                  color: Colors.white, size: 36),
                              SizedBox(height: 8),
                              Text('Map view • Nearby gigs around you',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<HomeMode>(
                segments: const [
                  ButtonSegment(
                      value: HomeMode.findWork, label: Text('Find Work')),
                  ButtonSegment(
                      value: HomeMode.postGig, label: Text('Post a Gig')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  setState(() => mode = selection.first);
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryVisuals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final category = categoryVisuals.keys.elementAt(index);
                    final emoji = categoryVisuals.values.elementAt(index);
                    final selected = selectedCategory == category;
                    return InkWell(
                      onTap: () => setState(() => selectedCategory = category),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 82,
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black12,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              category,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: mode == HomeMode.findWork
                    ? _FindWorkSection(
                        key: const ValueKey('findWork'),
                        isLoading: isLoading,
                        gigs: visibleGigs,
                        repository: widget.repository,
                      )
                    : _PostGigSection(
                        key: const ValueKey('postGig'),
                        repository: widget.repository,
                        onPosted: () => setState(() {}),
                      ),
              ),
            ],
          ),
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
          child: Text('No gigs in this category yet. Try another category.'),
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
              title: Text(gig.title),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${gig.category} • ${gig.providerName} • ${gig.location}'),
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
                  Text('\$${gig.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GigDetailScreen(gig: gig, repository: repository),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
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
              'Post a local task',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customer posts gig → worker accepts → customer pays upfront → escrow releases after completion.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final gig = await Navigator.of(context).push<Gig>(
                  MaterialPageRoute(builder: (_) => const PostGigScreen()),
                );
                if (gig != null) {
                  await repository.addGig(gig);
                  onPosted();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Gig Listing'),
            ),
          ],
        ),
      ),
    );
  }
}
