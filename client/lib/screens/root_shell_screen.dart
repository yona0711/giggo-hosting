import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gig_repository.dart';
import 'escrow_screen.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';
import 'service_page_tab_screen.dart';

class RootShellScreen extends StatefulWidget {
  const RootShellScreen({
    super.key,
    required this.repository,
    required this.onLoggedOut,
  });

  final GigRepository repository;
  final VoidCallback onLoggedOut;

  @override
  State<RootShellScreen> createState() => _RootShellScreenState();
}

class _RootShellScreenState extends State<RootShellScreen> {
  int currentIndex = 0;
  final Map<String, GlobalKey<NavigatorState>> _navigatorKeys = {};

  GlobalKey<NavigatorState> _navigatorKeyFor(String id) {
    return _navigatorKeys.putIfAbsent(id, () => GlobalKey<NavigatorState>());
  }

  List<_ShellTab> _tabsFor(bool isBusiness) {
    if (isBusiness) {
      return [
        _ShellTab(
          id: 'home',
          destination: const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Home',
          ),
          builder: () => HomeScreen(repository: widget.repository),
        ),
        _ShellTab(
          id: 'messages',
          destination: const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          builder: () => InboxScreen(repository: widget.repository),
        ),
        _ShellTab(
          id: 'service-page',
          destination: const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            label: 'Service Page',
          ),
          builder: () => ServicePageTabScreen(repository: widget.repository),
        ),
        _ShellTab(
          id: 'payments',
          destination: const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Payments',
          ),
          builder: () => EscrowScreen(repository: widget.repository),
        ),
        _ShellTab(
          id: 'profile',
          destination: const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          builder: () => ProfileScreen(
            repository: widget.repository,
            onLoggedOut: widget.onLoggedOut,
          ),
        ),
      ];
    }

    return [
      _ShellTab(
        id: 'home',
        destination: const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          label: 'Home',
        ),
        builder: () => HomeScreen(repository: widget.repository),
      ),
      _ShellTab(
        id: 'messages',
        destination: const NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Messages',
        ),
        builder: () => InboxScreen(repository: widget.repository),
      ),
      _ShellTab(
        id: 'profile',
        destination: const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
        builder: () => ProfileScreen(
          repository: widget.repository,
          onLoggedOut: widget.onLoggedOut,
        ),
      ),
    ];
  }

  Future<void> _handleBackNavigation() async {
    final tabs = _tabsFor(widget.repository.profileForView.isBusinessAccount);
    if (currentIndex >= tabs.length) {
      return;
    }

    final navigator = _navigatorKeyFor(tabs[currentIndex].id).currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (currentIndex != 0) {
      setState(() => currentIndex = 0);
      return;
    }

    SystemNavigator.pop();
  }

  void _handleDestinationSelected(int index, List<_ShellTab> tabs) {
    if (index == currentIndex) {
      _navigatorKeyFor(tabs[index].id)
          .currentState
          ?.popUntil((route) => route.isFirst);
      return;
    }

    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.repository.profileForView.isBusinessAccount;
    final tabs = _tabsFor(isBusiness);

    if (currentIndex >= tabs.length) {
      currentIndex = 0;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBackNavigation(),
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: tabs.map((tab) {
            return Navigator(
              key: _navigatorKeyFor(tab.id),
              onGenerateRoute: (_) {
                return MaterialPageRoute<void>(
                  builder: (_) => tab.builder(),
                );
              },
            );
          }).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) =>
              _handleDestinationSelected(index, tabs),
          destinations: tabs.map((tab) => tab.destination).toList(),
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.id,
    required this.destination,
    required this.builder,
  });

  final String id;
  final NavigationDestination destination;
  final Widget Function() builder;
}
