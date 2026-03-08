import 'package:flutter/material.dart';

import '../services/gig_repository.dart';
import 'login_screen.dart';
import 'root_shell_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key, required this.repository});

  final GigRepository repository;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isAuthenticated = false;

  void _handleAuthenticated() {
    if (!mounted) {
      return;
    }
    setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated && widget.repository.isLoggedIn) {
      return RootShellScreen(repository: widget.repository);
    }

    return LoginScreen(
      repository: widget.repository,
      onAuthenticated: _handleAuthenticated,
    );
  }
}
