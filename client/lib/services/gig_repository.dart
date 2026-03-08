import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/escrow_payment.dart';
import '../models/gig.dart';
import '../models/user_profile.dart';

class SignUpResult {
  const SignUpResult({
    this.errorMessage,
    this.infoMessage,
    this.requiresParentApproval = false,
  });

  final String? errorMessage;
  final String? infoMessage;
  final bool requiresParentApproval;
}

class GigRepository {
  GigRepository({
    http.Client? httpClient,
    this.baseUrl = 'http://localhost:4000',
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String baseUrl;

  UserProfile? _currentUser;

  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  final UserProfile _guestUser = const UserProfile(
    name: 'Avery Jordan',
    age: 16,
    rating: 4.8,
    completedGigs: 42,
    bio:
        'Reliable neighborhood helper for pet care, tutoring, and light tasks.',
    isVerified: true,
    backgroundChecked: false,
    skills: ['Dog Walking', 'Math Tutoring', 'Tech Setup', 'Car Wash'],
    hasParentMonitoring: true,
    parentPayoutApproval: true,
    payoutLimitPerWeek: 250,
  );

  UserProfile get profileForView => _currentUser ?? _guestUser;

  final List<Gig> _gigs = [
    Gig(
      id: 'g1',
      title: 'Dog Walking (30 mins)',
      description: 'Friendly neighborhood dog walking service.',
      category: 'Pet Care',
      price: 15,
      providerName: 'Mia R.',
      location: 'Downtown',
      minAge: 13,
    ),
    Gig(
      id: 'g2',
      title: 'Lawn Mowing + Edge Trim',
      description: 'Clean landscaping for front and back yard.',
      category: 'Landscaping',
      price: 45,
      providerName: 'Jordan T.',
      location: 'North Side',
      minAge: 13,
    ),
    Gig(
      id: 'g3',
      title: 'Basic Car Detailing',
      description: 'Exterior wash and interior vacuum package.',
      category: 'Car Care',
      price: 60,
      providerName: 'Chris A.',
      location: 'West End',
      minAge: 13,
    ),
    Gig(
      id: 'g4',
      title: 'Evening Babysitting (3 hours)',
      description: 'Watch 2 kids after school with light meal prep.',
      category: 'Home',
      price: 75,
      providerName: 'Taylor S.',
      location: 'Maple District',
      minAge: 18,
      requiresBackgroundCheck: true,
      isLateNight: true,
    ),
    Gig(
      id: 'g5',
      title: 'Laptop + Wi-Fi Setup',
      description: 'Home network setup, printer, and app installs.',
      category: 'Tech',
      price: 55,
      providerName: 'Nico P.',
      location: 'Harbor Point',
      minAge: 16,
    ),
    Gig(
      id: 'g6',
      title: 'Math Tutoring (1 hour)',
      description: 'Algebra and geometry tutoring for middle school students.',
      category: 'Tutoring',
      price: 35,
      providerName: 'Sam K.',
      location: 'Riverside',
      minAge: 13,
    ),
  ];

  final List<EscrowPayment> _payments = [];

  List<Gig> get gigs => List.unmodifiable(_gigs);
  List<EscrowPayment> get payments => List.unmodifiable(_payments);

  List<String> get categories => const [
        'All',
        'Pets',
        'Auto',
        'Home',
        'Tutoring',
        'Moving',
        'Cleaning',
        'Tech',
        'Pet Care',
        'Landscaping',
        'Car Care',
      ];

  List<Gig> gigsByCategory(String category) {
    if (category == 'All') {
      return List.unmodifiable(_gigs);
    }
    return _gigs.where((gig) => gig.category == category).toList();
  }

  bool canCurrentUserWorkGig(Gig gig) {
    final user = profileForView;
    if (user.age < gig.minAge) {
      return false;
    }
    if (user.isTeen && gig.isLateNight) {
      return false;
    }
    if (gig.requiresBackgroundCheck && !user.backgroundChecked) {
      return false;
    }
    return true;
  }

  String? restrictedReason(Gig gig) {
    final user = profileForView;
    if (user.age < gig.minAge) {
      return 'Requires age ${gig.minAge}+';
    }
    if (user.isTeen && gig.isLateNight) {
      return 'Teens cannot take late-night gigs';
    }
    if (gig.requiresBackgroundCheck && !user.backgroundChecked) {
      return 'Background check required';
    }
    return null;
  }

  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    String? parentEmail,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'dateOfBirth': dateOfBirth.toIso8601String(),
          'parentEmail': parentEmail,
        }),
      );

      if (response.statusCode == 201) {
        final userJson = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = UserProfile.fromAuthPayload(userJson);
        return const SignUpResult();
      }

      if (response.statusCode == 202) {
        return const SignUpResult(
          requiresParentApproval: true,
          infoMessage:
              'Parent approval required. Ask your parent to check their email to approve your account.',
        );
      }

      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return SignUpResult(
        errorMessage:
            (error['message'] as String?) ?? 'Unable to create account.',
      );
    } catch (_) {
      return const SignUpResult(
        errorMessage:
            'Cannot reach server. Please make sure backend is running.',
      );
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final userJson = jsonDecode(response.body) as Map<String, dynamic>;
        _currentUser = UserProfile.fromAuthPayload(userJson);
        return null;
      }

      final error = jsonDecode(response.body) as Map<String, dynamic>;
      return (error['message'] as String?) ?? 'Unable to sign in.';
    } catch (_) {
      return 'Cannot reach server. Please make sure backend is running.';
    }
  }

  void logout() {
    _currentUser = null;
  }

  double get platformCommissionRate => 0.15;

  Future<void> fetchGigs() async {
    try {
      final response = await _httpClient.get(Uri.parse('$baseUrl/api/gigs'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        _gigs
          ..clear()
          ..addAll(
            decoded.cast<Map<String, dynamic>>().map(Gig.fromJson).toList(),
          );
      }
    } catch (_) {
      // Keep fallback in-memory gigs when backend is not reachable.
    }
  }

  Future<Gig> addGig(Gig gig) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/gigs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(gig.toJson()),
      );

      if (response.statusCode == 201) {
        final createdGig = Gig.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _gigs.insert(0, createdGig);
        return createdGig;
      }
    } catch (_) {
      // Fall back below.
    }

    _gigs.insert(0, gig);
    return gig;
  }

  double platformFeeFor(double amount) => amount * platformCommissionRate;

  double workerPayoutFor(double amount) => amount - platformFeeFor(amount);

  Future<void> fetchEscrows() async {
    try {
      final response = await _httpClient.get(Uri.parse('$baseUrl/api/escrows'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        _payments
          ..clear()
          ..addAll(
            decoded
                .cast<Map<String, dynamic>>()
                .map(EscrowPayment.fromJson)
                .toList(),
          );
      }
    } catch (_) {
      // Keep fallback in-memory escrows when backend is not reachable.
    }
  }

  Future<EscrowPayment> createEscrow({
    required String gigId,
    required double amount,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/escrows'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'gigId': gigId, 'amount': amount}),
      );

      if (response.statusCode == 201) {
        final payment = EscrowPayment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _payments.insert(0, payment);
        return payment;
      }
    } catch (_) {
      // Fall back below.
    }

    final payment = EscrowPayment(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      gigId: gigId,
      amount: amount,
      status: EscrowStatus.pendingFunding,
    );

    _payments.insert(0, payment);
    return payment;
  }

  Future<void> fundEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/api/escrows/$escrowId/fund'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        payment.status = EscrowPayment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ).status;
        return;
      }
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.funded;
  }

  Future<void> releaseEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/api/escrows/$escrowId/release'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        payment.status = EscrowPayment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ).status;
        return;
      }
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.released;
  }

  Future<void> disputeEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      final response = await _httpClient.patch(
        Uri.parse('$baseUrl/api/escrows/$escrowId/dispute'),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        payment.status = EscrowPayment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        ).status;
        return;
      }
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.disputed;
  }
}
