import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/escrow_payment.dart';
import '../models/gig.dart';
import '../models/service_booking.dart';
import '../models/service_conversation.dart';
import '../models/service_message.dart';
import '../models/service_page.dart';
import '../models/user_profile.dart';

class SignUpResult {
  const SignUpResult({
    this.errorMessage,
    this.infoMessage,
    this.requiresParentApproval = false,
    this.childUid,
    this.approvalToken,
  });

  final String? errorMessage;
  final String? infoMessage;
  final bool requiresParentApproval;
  final String? childUid;
  final String? approvalToken;
}

class ProviderPayoutResult {
  const ProviderPayoutResult({
    this.accountId,
    this.onboardingUrl,
    this.errorMessage,
  });

  final String? accountId;
  final String? onboardingUrl;
  final String? errorMessage;
}

class PaymentSetupResult {
  const PaymentSetupResult({
    this.url,
    this.mode,
    this.cardBrand,
    this.cardLast4,
    this.errorMessage,
  });

  final String? url;
  final String? mode;
  final String? cardBrand;
  final String? cardLast4;
  final String? errorMessage;
}

class GigRepository {
  GigRepository({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? _defaultBaseUrl(),
        _auth = FirebaseAuth.instance,
        _firestore = FirebaseFirestore.instance;

  final http.Client _httpClient;
  final String baseUrl;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const String _createTeenApprovalTokenUrl =
      'https://us-central1-giggo-8a302.cloudfunctions.net/createTeenApprovalToken';
  static const String _approveTeenAccountUrl =
      'https://us-central1-giggo-8a302.cloudfunctions.net/approveTeenAccount';

  static String _defaultBaseUrl() {
    if (!kIsWeb) {
      return 'http://localhost:4000';
    }

    final origin = Uri.base.origin;
    if (origin.startsWith('http://localhost') ||
        origin.startsWith('http://127.0.0.1')) {
      return 'http://localhost:4000';
    }
    return origin;
  }

  CollectionReference<Map<String, dynamic>> get _gigsCollection =>
      _firestore.collection('gigs');
  CollectionReference<Map<String, dynamic>> get _escrowsCollection =>
      _firestore.collection('escrows');
  CollectionReference<Map<String, dynamic>> get _servicePagesCollection =>
      _firestore.collection('servicePages');
  CollectionReference<Map<String, dynamic>>
      get _serviceConversationsCollection =>
          _firestore.collection('serviceConversations');
  CollectionReference<Map<String, dynamic>> get _serviceBookingsCollection =>
      _firestore.collection('serviceBookings');
  CollectionReference<Map<String, dynamic>> get _trustReportsCollection =>
      _firestore.collection('trustReports');

  UserProfile? _currentUser;

  UserProfile? get currentUser => _currentUser;
  String? get currentUserUid => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;
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
    isBusinessAccount: false,
  );

  UserProfile get profileForView => _currentUser ?? _guestUser;
  static const double providerSubscriptionMonthlyPrice = 19.99;
  static const double standardPlatformCommissionRate = 0.20;

  bool get hasActiveProviderSubscription =>
      profileForView.providerSubscriptionActive;

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
      tags: ['dog walking', 'pets', 'pet care', 'exercise'],
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
      tags: ['lawn mowing', 'yard work', 'landscaping', 'edge trim'],
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
      tags: ['car wash', 'detailing', 'auto', 'interior cleaning'],
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
      isLateNight: true,
      tags: ['babysitting', 'child care', 'evening help', 'home'],
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
      tags: ['wifi setup', 'laptop setup', 'tech help', 'printer'],
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
      tags: ['math tutoring', 'algebra', 'geometry', 'homework help'],
    ),
  ];

  final List<EscrowPayment> _payments = [];
  final Map<String, ServicePage> _localServicePageCache =
      <String, ServicePage>{};

  List<Gig> get gigs => List.unmodifiable(_gigs);
  List<EscrowPayment> get payments => List.unmodifiable(_payments);

  List<EscrowPayment> get releasedPayments => _payments
      .where((payment) => payment.status == EscrowStatus.released)
      .toList();

  Map<int, double> get totalReceivedByYear {
    final totals = <int, double>{};
    for (final payment in releasedPayments) {
      final year = payment.createdAt?.year ?? DateTime.now().year;
      totals[year] = (totals[year] ?? 0) + payment.amount;
    }
    return totals;
  }

  String _slugify(String input) {
    final lower = input.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    final dashed = cleaned.replaceAll(RegExp(r'\s+'), '-');
    return dashed
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids.first}__${ids.last}';
  }

  String _bookingSlotKey(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y$m$d$h$mm';
  }

  String _bookingDocId(String providerUid, DateTime dateTime) {
    return '${providerUid}__${_bookingSlotKey(dateTime)}';
  }

  Stream<List<T>> _safeListStream<T>(Stream<List<T>> source) {
    return (() async* {
      try {
        await for (final items in source) {
          yield items;
        }
      } catch (_) {
        yield <T>[];
      }
    }())
        .asBroadcastStream();
  }

  Future<String?> _providerPaymentAccountId(String providerUid) async {
    try {
      final providerDoc =
          await _firestore.collection('users').doc(providerUid).get();
      final data = providerDoc.data();
      final accountId = data?['stripeAccountId'] as String?;
      if (accountId != null && accountId.trim().isNotEmpty) {
        return accountId.trim();
      }
    } catch (_) {
      // Keep optional fallback below.
    }
    return null;
  }

  Future<String?> fetchMyStripeAccountId() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    return _providerPaymentAccountId(uid);
  }

  Future<bool> fetchProviderSubscriptionActive(String providerUid) async {
    if (providerUid.isEmpty) {
      return false;
    }
    if (providerUid == _auth.currentUser?.uid) {
      return hasActiveProviderSubscription;
    }
    try {
      final doc = await _firestore.collection('users').doc(providerUid).get();
      return (doc.data()?['providerSubscriptionActive'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> activateProviderSubscription() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Login required to subscribe.');
    }
    final renewsAt = DateTime.now().toUtc().add(const Duration(days: 30));
    try {
      await _firestore.collection('users').doc(uid).set({
        'providerSubscriptionActive': true,
        'providerSubscriptionMonthlyPrice': providerSubscriptionMonthlyPrice,
        'providerSubscriptionRenewsAt': Timestamp.fromDate(renewsAt),
        'providerSubscriptionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _servicePagesCollection.doc(uid).set({
        'providerSubscriptionActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep local state so mock/offline mode still reflects the subscription.
    }
    final cachedPage = _localServicePageCache[uid];
    if (cachedPage != null) {
      _localServicePageCache[uid] =
          cachedPage.copyWith(providerSubscriptionActive: true);
    }
    _currentUser = profileForView.copyWith(
      providerSubscriptionActive: true,
      providerSubscriptionRenewsAt: renewsAt,
    );
  }

  Future<void> cancelProviderSubscription() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Login required to manage subscription.');
    }
    try {
      await _firestore.collection('users').doc(uid).set({
        'providerSubscriptionActive': false,
        'providerSubscriptionUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _servicePagesCollection.doc(uid).set({
        'providerSubscriptionActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep local state so mock/offline mode still reflects cancellation.
    }
    final cachedPage = _localServicePageCache[uid];
    if (cachedPage != null) {
      _localServicePageCache[uid] =
          cachedPage.copyWith(providerSubscriptionActive: false);
    }
    _currentUser = profileForView.copyWith(
      providerSubscriptionActive: false,
    );
  }

  String _extractApiErrorMessage(dynamic body, String fallback) {
    if (body is Map<String, dynamic>) {
      final message = body['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return fallback;
  }

  Future<ProviderPayoutResult> ensureMyStripeConnectAccount() async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    if (uid == null || email == null || email.trim().isEmpty) {
      return const ProviderPayoutResult(
        errorMessage: 'Login required to create payout account.',
      );
    }

    final existing = await _providerPaymentAccountId(uid);
    if (existing != null && existing.isNotEmpty) {
      try {
        await _httpClient.post(
          Uri.parse('$baseUrl/api/providers/connect-account'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'providerUid': uid,
            'email': email.trim().toLowerCase(),
            'accountId': existing,
          }),
        );
      } catch (_) {}
      return ProviderPayoutResult(accountId: existing);
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/providers/connect-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerUid': uid,
          'email': email.trim().toLowerCase(),
        }),
      );

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final accountId = (body is Map<String, dynamic>)
            ? body['accountId'] as String?
            : null;
        if (accountId != null && accountId.trim().isNotEmpty) {
          try {
            await _firestore.collection('users').doc(uid).set({
              'stripeAccountId': accountId.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
          return ProviderPayoutResult(accountId: accountId.trim());
        }

        return const ProviderPayoutResult(
          errorMessage: 'Payment service did not return an account id.',
        );
      }

      return ProviderPayoutResult(
        errorMessage: _extractApiErrorMessage(
          body,
          'Unable to create payout account.',
        ),
      );
    } catch (_) {
      return const ProviderPayoutResult(
        errorMessage: 'Unable to reach payment service. Please try again.',
      );
    }
  }

  Future<ProviderPayoutResult> createMyStripeOnboardingLink() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const ProviderPayoutResult(
        errorMessage: 'Login required to continue onboarding.',
      );
    }

    final existingAccountId = await _providerPaymentAccountId(uid);

    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/providers/$uid/onboarding-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accountId': existingAccountId,
        }),
      );

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final url =
            (body is Map<String, dynamic>) ? body['url'] as String? : null;
        if (url != null && url.trim().isNotEmpty) {
          return ProviderPayoutResult(onboardingUrl: url.trim());
        }

        return const ProviderPayoutResult(
          errorMessage: 'Unable to generate onboarding link.',
        );
      }

      return ProviderPayoutResult(
        errorMessage: _extractApiErrorMessage(
          body,
          'Unable to generate onboarding link.',
        ),
      );
    } catch (_) {
      return const ProviderPayoutResult(
        errorMessage: 'Unable to reach payment service. Please try again.',
      );
    }
  }

  Future<PaymentSetupResult> createStripePaymentSetupLink() async {
    final uid = _auth.currentUser?.uid;
    final email = _auth.currentUser?.email;
    if (uid == null || email == null || email.trim().isEmpty) {
      return const PaymentSetupResult(
        errorMessage: 'Login required to add a payment method.',
      );
    }

    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/payments/setup-card-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userUid': uid,
          'email': email.trim().toLowerCase(),
          'name': profileForView.name,
        }),
      );

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final url =
            body is Map<String, dynamic> ? body['url'] as String? : null;
        if (url == null || url.trim().isEmpty) {
          return const PaymentSetupResult(
            errorMessage: 'Payment service did not return a setup link.',
          );
        }
        return PaymentSetupResult(
          url: url.trim(),
          mode: body is Map<String, dynamic> ? body['mode'] as String? : null,
          cardBrand: body is Map<String, dynamic>
              ? body['cardBrand'] as String?
              : null,
          cardLast4: body is Map<String, dynamic>
              ? body['cardLast4'] as String?
              : null,
        );
      }

      return PaymentSetupResult(
        errorMessage: _extractApiErrorMessage(
          body,
          'Unable to create secure payment setup link.',
        ),
      );
    } catch (_) {
      return const PaymentSetupResult(
        errorMessage: 'Unable to reach payment service. Please try again.',
      );
    }
  }

  Future<PaymentSetupResult> fetchStripePaymentMethodStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const PaymentSetupResult(
        errorMessage: 'Login required to load payment method.',
      );
    }

    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/payments/setup-card-status/$uid'),
      );

      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return PaymentSetupResult(
          mode: body is Map<String, dynamic> ? body['mode'] as String? : null,
          cardBrand: body is Map<String, dynamic>
              ? body['cardBrand'] as String?
              : null,
          cardLast4: body is Map<String, dynamic>
              ? body['cardLast4'] as String?
              : null,
        );
      }

      return PaymentSetupResult(
        errorMessage: _extractApiErrorMessage(
          body,
          'Unable to load payment method.',
        ),
      );
    } catch (_) {
      return const PaymentSetupResult(
        errorMessage: 'Unable to reach payment service.',
      );
    }
  }

  Future<
      ({
        String? paymentIntentId,
        String mode,
        String status,
        String? error,
      })> _authorizeEscrowPayment({
    required String bookingId,
    required String serviceTitle,
    required String clientUid,
    required String providerUid,
    required double amount,
    required bool providerSubscriptionActive,
  }) async {
    final providerAccountId = await _providerPaymentAccountId(providerUid);
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/payments/escrow-authorize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'currency': 'usd',
          'bookingId': bookingId,
          'serviceTitle': serviceTitle,
          'clientUid': clientUid,
          'providerUid': providerUid,
          'providerAccountId': providerAccountId,
          'providerSubscriptionActive': providerSubscriptionActive,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body is Map<String, dynamic>) {
          final status = (body['status'] as String?) ?? 'unknown';
          return (
            paymentIntentId: body['paymentIntentId'] as String?,
            mode: (body['mode'] as String?) ?? 'mock',
            status: status,
            error: null,
          );
        }
      }

      if (body is Map<String, dynamic>) {
        return (
          paymentIntentId: null,
          mode: 'unknown',
          status: 'failed',
          error: (body['message'] as String?) ?? 'Unable to authorize payment.',
        );
      }

      return (
        paymentIntentId: null,
        mode: 'unknown',
        status: 'failed',
        error: 'Unable to authorize payment.',
      );
    } catch (_) {
      return (
        paymentIntentId: null,
        mode: 'offline',
        status: 'failed',
        error: 'Unable to reach payment service. Please try again.',
      );
    }
  }

  ServicePage _defaultServicePageForCurrentUser() {
    final uid = _auth.currentUser?.uid ?? '';
    final profile = profileForView;
    final slugBase = _slugify(profile.name);
    return ServicePage(
      ownerUid: uid,
      ownerName: profile.name,
      title: '${profile.name} Services',
      about: profile.bio,
      city: 'Local Area',
      categories: profile.skills.take(4).toList(),
      imageUrls: const [],
      shareSlug:
          '$slugBase-${uid.isNotEmpty ? uid.substring(0, uid.length >= 6 ? 6 : uid.length) : 'local'}',
      providerSubscriptionActive: profile.providerSubscriptionActive,
    );
  }

  Future<ServicePage> fetchOrCreateOwnServicePage() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Login required to manage a service page.');
    }

    final cached = _localServicePageCache[uid];
    if (cached != null) {
      return cached;
    }

    try {
      final doc = await _servicePagesCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final loaded = ServicePage.fromJson(doc.data()!);
        _localServicePageCache[uid] = loaded;
        return loaded;
      }

      final created = _defaultServicePageForCurrentUser();
      await _servicePagesCollection.doc(uid).set({
        ...created.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _localServicePageCache[uid] = created;
      return created;
    } catch (_) {
      final fallback = _defaultServicePageForCurrentUser();
      _localServicePageCache[uid] = fallback;
      return fallback;
    }
  }

  Future<ServicePage> upsertOwnServicePage(ServicePage page) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Login required to update service page.');
    }

    final profile = profileForView;
    final normalizedSlug =
        _slugify(page.shareSlug.isEmpty ? page.title : page.shareSlug);
    final safeSlug = normalizedSlug.isEmpty
        ? '${_slugify(profile.name)}-${uid.substring(0, uid.length >= 6 ? 6 : uid.length)}'
        : normalizedSlug;

    final updated = page.copyWith(
      ownerUid: uid,
      ownerName: profile.name,
      shareSlug: safeSlug,
    );

    try {
      await _servicePagesCollection.doc(uid).set({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep local cache fallback below.
    }

    _localServicePageCache[uid] = updated;

    return updated;
  }

  Future<ServicePage?> fetchServicePageBySlug(String slug) async {
    final normalized = _slugify(slug);
    if (normalized.isEmpty) {
      return null;
    }

    ServicePage? cachedPage() {
      for (final page in _localServicePageCache.values) {
        if (_slugify(page.shareSlug) == normalized) {
          return page;
        }
      }
      return null;
    }

    try {
      final query = await _servicePagesCollection
          .where('shareSlug', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return cachedPage();
      }

      return ServicePage.fromJson(query.docs.first.data());
    } catch (_) {
      return cachedPage();
    }
  }

  Future<ServicePage?> fetchServicePageByOwnerUid(String ownerUid) async {
    try {
      final doc = await _servicePagesCollection.doc(ownerUid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ServicePage.fromJson(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  Future<ServicePage> fetchOrCreateServicePageForGig(Gig gig) async {
    final providerUid = gig.providerUid;
    if (providerUid == null || providerUid.trim().isEmpty) {
      throw StateError('Provider service page is not available yet.');
    }

    final existing = await fetchServicePageByOwnerUid(providerUid);
    if (existing != null) {
      return existing;
    }

    final providerGigs = await fetchGigsByProviderUid(providerUid);
    final relatedGigs = providerGigs.isEmpty ? <Gig>[gig] : providerGigs;
    final categories = relatedGigs
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    final imageUrls = relatedGigs
        .expand((item) => item.imageUrls)
        .where((url) => url.trim().isNotEmpty)
        .toSet()
        .toList();
    final locations = relatedGigs
        .map((item) => item.location.trim())
        .where((location) => location.isNotEmpty)
        .toSet()
        .toList();
    final slugBase = _slugify(gig.providerName);
    final suffix =
        providerUid.length >= 6 ? providerUid.substring(0, 6) : providerUid;

    final created = ServicePage(
      ownerUid: providerUid,
      ownerName: gig.providerName,
      title: '${gig.providerName} Services',
      about: gig.description.trim().isNotEmpty
          ? gig.description.trim()
          : 'Reliable local services from ${gig.providerName}.',
      city: locations.isNotEmpty ? locations.first : gig.location,
      categories: categories.isNotEmpty ? categories : <String>[gig.category],
      imageUrls: imageUrls,
      shareSlug: '${slugBase.isEmpty ? 'provider' : slugBase}-$suffix',
      heroHeadline: 'Book ${gig.providerName} on Giggo',
      announcement: 'Now accepting service requests through Giggo.',
      providerSubscriptionActive:
          await fetchProviderSubscriptionActive(providerUid),
    );

    try {
      await _servicePagesCollection.doc(providerUid).set({
        ...created.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // The caller can still preview the generated page if rules block writes.
    }

    _localServicePageCache[providerUid] = created;
    return created;
  }

  String servicePageLink(ServicePage page) {
    if (kIsWeb) {
      return '${Uri.base.origin}/#/service/${page.shareSlug}';
    }
    return 'giggo://service/${page.shareSlug}';
  }

  Future<void> sendMessageToProvider({
    required String providerUid,
    required String providerName,
    required String text,
  }) async {
    final clientUid = _auth.currentUser?.uid;
    final trimmedText = text.trim();
    if (clientUid == null) {
      throw StateError('Please log in to send a message.');
    }
    if (trimmedText.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    if (await isUserBlocked(providerUid)) {
      throw StateError('Unblock this provider before sending a message.');
    }

    final conversationId = _conversationId(clientUid, providerUid);
    final clientName = _currentUser?.name ??
        _auth.currentUser?.email?.split('@').first ??
        'Client';

    await _serviceConversationsCollection.doc(conversationId).set({
      'providerUid': providerUid,
      'providerName': providerName,
      'clientUid': clientUid,
      'clientName': clientName,
      'participantUids': [providerUid, clientUid],
      'lastMessage': trimmedText,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _serviceConversationsCollection
        .doc(conversationId)
        .collection('messages')
        .add({
      'senderUid': clientUid,
      'senderName': clientName,
      'text': trimmedText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> replyInConversation({
    required String conversationId,
    required String text,
  }) async {
    final senderUid = _auth.currentUser?.uid;
    final trimmedText = text.trim();
    if (senderUid == null) {
      throw StateError('Please log in to send a message.');
    }
    if (trimmedText.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    final conversationDoc =
        await _serviceConversationsCollection.doc(conversationId).get();
    final conversationData = conversationDoc.data();
    final providerUid = conversationData?['providerUid'] as String?;
    final clientUid = conversationData?['clientUid'] as String?;
    final otherUid = providerUid == senderUid ? clientUid : providerUid;
    if (otherUid != null && await isUserBlocked(otherUid)) {
      throw StateError('Unblock this user before sending a message.');
    }

    final senderName = _currentUser?.name ??
        _auth.currentUser?.email?.split('@').first ??
        'User';
    await _serviceConversationsCollection
        .doc(conversationId)
        .collection('messages')
        .add({
      'senderUid': senderUid,
      'senderName': senderName,
      'text': trimmedText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _serviceConversationsCollection.doc(conversationId).set({
      'lastMessage': trimmedText,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ServiceConversation>> watchMyConversations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const <ServiceConversation>[]);
    }

    return _safeListStream(
      _serviceConversationsCollection
          .where('participantUids', arrayContains: uid)
          .orderBy('lastUpdated', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceConversation.fromJson(doc.id, doc.data()))
              .toList()),
    );
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return <String>{};
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final values = doc.data()?['blockedUserIds'] as List?;
      return values?.whereType<String>().toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> isUserBlocked(String userUid) async {
    if (userUid.isEmpty) {
      return false;
    }
    final blocked = await fetchBlockedUserIds();
    return blocked.contains(userUid);
  }

  Future<void> blockUser({
    required String userUid,
    required String userName,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please log in to block users.');
    }
    if (userUid.isEmpty || userUid == uid) {
      throw StateError('Unable to block this account.');
    }
    await _firestore.collection('users').doc(uid).set({
      'blockedUserIds': FieldValue.arrayUnion([userUid]),
      'blockedUsers': {
        userUid: {
          'name': userName,
          'blockedAt': FieldValue.serverTimestamp(),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String userUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Please log in to unblock users.');
    }
    await _firestore.collection('users').doc(uid).set({
      'blockedUserIds': FieldValue.arrayRemove([userUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reportContent({
    required String contentType,
    required String targetId,
    required String targetOwnerUid,
    required String targetOwnerName,
    required String reason,
    String details = '',
  }) async {
    final reporterUid = _auth.currentUser?.uid;
    if (reporterUid == null) {
      throw StateError('Please log in to report content.');
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Choose a reason before submitting a report.');
    }
    await _trustReportsCollection.add({
      'contentType': contentType,
      'targetId': targetId,
      'targetOwnerUid': targetOwnerUid,
      'targetOwnerName': targetOwnerName,
      'reporterUid': reporterUid,
      'reporterName': _currentUser?.name ?? 'Giggo user',
      'reason': trimmedReason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ServiceMessage>> watchConversationMessages(
      String conversationId) {
    return _safeListStream(
      _serviceConversationsCollection
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) =>
                  ServiceMessage.fromJson(doc.id, conversationId, doc.data()))
              .toList()),
    );
  }

  Stream<List<ServiceBooking>> watchProviderBookings(String providerUid) {
    return _safeListStream(
      _serviceBookingsCollection
          .where('providerUid', isEqualTo: providerUid)
          .snapshots()
          .map((snapshot) {
        final bookings = snapshot.docs
            .map((doc) => ServiceBooking.fromJson(doc.id, doc.data()))
            .toList();
        bookings.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        return bookings;
      }),
    );
  }

  Stream<List<ServiceBooking>> watchMyProviderBookings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const <ServiceBooking>[]);
    }
    return watchProviderBookings(uid);
  }

  Stream<List<ServiceBooking>> watchGuardianPendingBookings() {
    final guardianEmail = _auth.currentUser?.email?.trim().toLowerCase();
    if (guardianEmail == null || guardianEmail.isEmpty) {
      return Stream.value(const <ServiceBooking>[]);
    }

    return _safeListStream(
      _serviceBookingsCollection
          .where('guardianEmail', isEqualTo: guardianEmail)
          .where('guardianApprovalStatus', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) {
        final bookings = snapshot.docs
            .map((doc) => ServiceBooking.fromJson(doc.id, doc.data()))
            .toList();
        bookings.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
        return bookings;
      }),
    );
  }

  Future<String?> approveGuardianBooking(ServiceBooking booking) async {
    final guardianUid = _auth.currentUser?.uid;
    final guardianEmail = _auth.currentUser?.email?.trim().toLowerCase();
    if (guardianUid == null || guardianEmail == null) {
      return 'Parent login required to approve this booking.';
    }
    if (guardianEmail != booking.guardianEmail.trim().toLowerCase()) {
      return 'This booking is assigned to a different parent email.';
    }
    if (!booking.pendingGuardianApproval) {
      return 'This booking does not need parent approval.';
    }

    final authorization = await _authorizeEscrowPayment(
      bookingId: booking.id,
      serviceTitle: booking.serviceTitle,
      clientUid: booking.clientUid,
      providerUid: booking.providerUid,
      amount: booking.escrowAmount,
      providerSubscriptionActive: booking.providerSubscriptionActive,
    );

    if (authorization.error != null) {
      return authorization.error;
    }

    final escrowStatus = authorization.status == 'succeeded'
        ? EscrowStatus.funded
        : EscrowStatus.pendingFunding;
    final escrowId = 'escrow__${booking.id}';

    try {
      await _firestore.runTransaction((transaction) async {
        final bookingRef = _serviceBookingsCollection.doc(booking.id);
        final escrowRef = _escrowsCollection.doc(escrowId);
        final existing = await transaction.get(bookingRef);
        if (!existing.exists) {
          throw StateError('Booking was not found.');
        }
        final current = ServiceBooking.fromJson(
          existing.id,
          existing.data() ?? <String, dynamic>{},
        );
        if (!current.pendingGuardianApproval) {
          throw StateError('This booking has already been reviewed.');
        }

        transaction.set(
          bookingRef,
          {
            'guardianApprovalStatus': 'approved',
            'guardianPresenceConfirmed': true,
            'guardianUid': guardianUid,
            'guardianApprovedAt': FieldValue.serverTimestamp(),
            'paymentStatus': escrowStatus.name,
            'processorPaymentId': authorization.paymentIntentId,
            'processorMode': authorization.mode,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          escrowRef,
          {
            'gigId': booking.serviceTitle,
            'amount': booking.escrowAmount,
            'status': escrowStatus.name,
            'bookingId': booking.id,
            'serviceTitle': booking.serviceTitle,
            'clientUid': booking.clientUid,
            'providerUid': booking.providerUid,
            'processorPaymentId': authorization.paymentIntentId,
            'processorMode': authorization.mode,
            'guardianUid': guardianUid,
            'guardianPresenceConfirmed': true,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _payments.insert(
        0,
        EscrowPayment(
          id: escrowId,
          gigId: booking.serviceTitle,
          amount: booking.escrowAmount,
          status: escrowStatus,
          bookingId: booking.id,
          serviceTitle: booking.serviceTitle,
          clientUid: booking.clientUid,
          providerUid: booking.providerUid,
          processorPaymentId: authorization.paymentIntentId,
          processorMode: authorization.mode,
        ),
      );

      return null;
    } on StateError catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to approve this booking.';
    }
  }

  Future<String?> declineGuardianBooking(ServiceBooking booking) async {
    final guardianUid = _auth.currentUser?.uid;
    final guardianEmail = _auth.currentUser?.email?.trim().toLowerCase();
    if (guardianUid == null || guardianEmail == null) {
      return 'Parent login required to decline this booking.';
    }
    if (guardianEmail != booking.guardianEmail.trim().toLowerCase()) {
      return 'This booking is assigned to a different parent email.';
    }

    try {
      await _serviceBookingsCollection.doc(booking.id).set({
        'guardianApprovalStatus': 'declined',
        'guardianPresenceConfirmed': false,
        'guardianUid': guardianUid,
        'guardianReviewedAt': FieldValue.serverTimestamp(),
        'paymentStatus': 'notFunded',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } catch (_) {
      return 'Unable to decline this booking.';
    }
  }

  Future<List<Gig>> fetchGigsByProviderUid(String providerUid) async {
    await fetchGigs();
    return _gigs
        .where((gig) =>
            gig.providerUid != null &&
            gig.providerUid == providerUid &&
            gig.isActive)
        .toList();
  }

  Future<String?> bookServiceDate({
    required String providerUid,
    required String providerName,
    required String serviceTitle,
    required DateTime date,
    required String customerAddress,
    required double escrowAmount,
    required bool providerSubscriptionActive,
    String notes = '',
  }) async {
    final clientUid = _auth.currentUser?.uid;
    if (clientUid == null) {
      return 'Please log in to book this service.';
    }
    if (clientUid == providerUid) {
      return 'You cannot book your own service.';
    }

    if (date.isBefore(DateTime.now())) {
      return 'Please select a future available time slot.';
    }

    final trimmedAddress = customerAddress.trim();
    if (trimmedAddress.isEmpty) {
      return 'Please provide the service address for this booking.';
    }

    if (escrowAmount <= 0) {
      return 'Unable to process payment. Invalid service amount.';
    }

    final docId = _bookingDocId(providerUid, date);
    final docRef = _serviceBookingsCollection.doc(docId);
    final escrowId = 'escrow__$docId';
    final escrowRef = _escrowsCollection.doc(escrowId);
    final clientName = _currentUser?.name ??
        _auth.currentUser?.email?.split('@').first ??
        'Client';
    final clientProfile = profileForView;
    final requiresGuardianApproval =
        clientProfile.requiresGuardianServiceApproval;
    final guardianEmail = clientProfile.parentEmail.trim().toLowerCase();

    if (requiresGuardianApproval && guardianEmail.isEmpty) {
      return 'Parent account link is required before booking services.';
    }

    ({
      String? paymentIntentId,
      String mode,
      String status,
      String? error,
    })? authorization;
    EscrowStatus escrowStatus = EscrowStatus.pendingFunding;

    if (!requiresGuardianApproval) {
      authorization = await _authorizeEscrowPayment(
        bookingId: docId,
        serviceTitle: serviceTitle,
        clientUid: clientUid,
        providerUid: providerUid,
        amount: escrowAmount,
        providerSubscriptionActive: providerSubscriptionActive,
      );

      if (authorization.error != null) {
        return authorization.error;
      }

      escrowStatus = authorization.status == 'succeeded'
          ? EscrowStatus.funded
          : EscrowStatus.pendingFunding;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(docRef);
        if (existing.exists) {
          throw StateError('This date is already booked. Choose another date.');
        }

        transaction.set(docRef, {
          'providerUid': providerUid,
          'providerName': providerName,
          'clientUid': clientUid,
          'clientName': clientName,
          'serviceTitle': serviceTitle,
          'scheduledDate': Timestamp.fromDate(date),
          'slotKey': _bookingSlotKey(date),
          'customerAddress': trimmedAddress,
          'notes': notes.trim(),
          'escrowAmount': escrowAmount,
          'providerSubscriptionActive': providerSubscriptionActive,
          'requiresGuardianApproval': requiresGuardianApproval,
          'guardianEmail': requiresGuardianApproval ? guardianEmail : '',
          'guardianApprovalStatus':
              requiresGuardianApproval ? 'pending' : 'notRequired',
          'guardianPresenceConfirmed': !requiresGuardianApproval,
          'paymentStatus': requiresGuardianApproval
              ? 'pendingGuardianApproval'
              : escrowStatus.name,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!requiresGuardianApproval) {
          transaction.set(
            escrowRef,
            {
              'gigId': serviceTitle,
              'amount': escrowAmount,
              'status': escrowStatus.name,
              'bookingId': docId,
              'serviceTitle': serviceTitle,
              'clientUid': clientUid,
              'providerUid': providerUid,
              'processorPaymentId': authorization?.paymentIntentId,
              'processorMode': authorization?.mode,
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });

      if (!requiresGuardianApproval) {
        _payments.insert(
          0,
          EscrowPayment(
            id: escrowId,
            gigId: serviceTitle,
            amount: escrowAmount,
            status: escrowStatus,
            bookingId: docId,
            serviceTitle: serviceTitle,
            clientUid: clientUid,
            providerUid: providerUid,
            processorPaymentId: authorization?.paymentIntentId,
            processorMode: authorization?.mode,
          ),
        );
      }

      return null;
    } on StateError catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to complete booking. That slot may already be taken.';
    }
  }

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
    final activeGigs = _gigs.where((gig) => gig.isActive).toList();
    if (category == 'All') {
      return List.unmodifiable(activeGigs);
    }
    return activeGigs.where((gig) => gig.category == category).toList();
  }

  bool canCurrentUserWorkGig(Gig gig) {
    final user = profileForView;
    if (user.age < gig.minAge) {
      return false;
    }
    if (user.isTeen && gig.isLateNight) {
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
    return null;
  }

  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    final birthdayThisYear =
        DateTime(now.year, dateOfBirth.month, dateOfBirth.day);
    if (now.isBefore(birthdayThisYear)) {
      age -= 1;
    }
    return age;
  }

  UserProfile _profileFromFirestore(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    final parsedAge = (json['age'] as num?)?.toInt() ?? 18;
    final approvalStatus = (json['approvalStatus'] as String?) ?? 'approved';
    final skills = (json['skills'] as List?)
            ?.whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        <String>['Getting Started'];
    final renewsAtValue = json['providerSubscriptionRenewsAt'];
    final renewsAt = renewsAtValue is Timestamp
        ? renewsAtValue.toDate()
        : renewsAtValue is DateTime
            ? renewsAtValue
            : null;

    final isTeen = parsedAge >= 13 && parsedAge <= 17;
    return UserProfile(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : fallbackName,
      age: parsedAge,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      completedGigs: (json['completedGigs'] as num?)?.toInt() ?? 0,
      bio: (json['bio'] as String?)?.trim().isNotEmpty == true
          ? (json['bio'] as String).trim()
          : 'New to Giggo.',
      isVerified: (json['isVerified'] as bool?) ?? false,
      backgroundChecked: (json['backgroundChecked'] as bool?) ?? false,
      skills: skills,
      hasParentMonitoring: (json['hasParentMonitoring'] as bool?) ?? isTeen,
      parentPayoutApproval: (json['parentPayoutApproval'] as bool?) ??
          (isTeen && approvalStatus == 'approved'),
      payoutLimitPerWeek:
          (json['payoutLimitPerWeek'] as num?)?.toInt() ?? (isTeen ? 250 : 0),
      isBusinessAccount: (json['isBusinessAccount'] as bool?) ?? false,
      providerSubscriptionActive:
          (json['providerSubscriptionActive'] as bool?) ?? false,
      providerSubscriptionRenewsAt: renewsAt,
      parentEmail: (json['parentEmail'] as String?) ?? '',
      approvalStatus: approvalStatus,
    );
  }

  Future<(String?, String?)> _requestTeenApprovalToken({
    required String childUid,
    required String parentEmail,
  }) async {
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) {
        return (
          null,
          'Unable to initialize parent approval. Please try again.'
        );
      }

      final response = await _httpClient.post(
        Uri.parse(_createTeenApprovalTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'childUid': childUid,
          'parentEmail': parentEmail,
        }),
      );

      final payload = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (payload is Map<String, dynamic>) {
          final token = payload['approvalToken'] as String?;
          if (token != null && token.isNotEmpty) {
            return (token, null);
          }
        }
        return (
          null,
          'Unable to initialize parent approval. Please try again.'
        );
      }

      if (payload is Map<String, dynamic>) {
        return (
          null,
          (payload['message'] as String?) ??
              'Unable to initialize parent approval.',
        );
      }

      return (null, 'Unable to initialize parent approval.');
    } catch (_) {
      return (null, 'Unable to initialize parent approval.');
    }
  }

  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required bool isBusinessAccount,
    String? parentEmail,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedParentEmail = (parentEmail ?? '').trim().toLowerCase();
    final age = _calculateAge(dateOfBirth);
    final isTeen = age >= 13 && age <= 17;

    if (age < 13) {
      return const SignUpResult(
        errorMessage: 'Minimum age to create an account is 13.',
      );
    }

    if (isTeen && !normalizedParentEmail.contains('@')) {
      return const SignUpResult(
        errorMessage: 'Parent email is required for ages 13-17.',
      );
    }

    if (normalizedParentEmail.isNotEmpty &&
        normalizedParentEmail == normalizedEmail) {
      return const SignUpResult(
        errorMessage: 'Parent email must be different from account email.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;

      if (user == null) {
        return const SignUpResult(errorMessage: 'Unable to create account.');
      }

      final approvalStatus = isTeen ? 'pending' : 'approved';

      await _firestore.collection('users').doc(user.uid).set({
        'name': normalizedName,
        'email': normalizedEmail,
        'age': age,
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'parentEmail': isTeen ? normalizedParentEmail : '',
        'approvalStatus': approvalStatus,
        'hasParentMonitoring': isTeen,
        'parentPayoutApproval': isTeen,
        'payoutLimitPerWeek': isTeen ? 250 : 0,
        'isBusinessAccount': isBusinessAccount,
        'providerSubscriptionActive': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (isTeen) {
        final (approvalToken, tokenError) = await _requestTeenApprovalToken(
          childUid: user.uid,
          parentEmail: normalizedParentEmail,
        );

        if (tokenError != null || approvalToken == null) {
          try {
            await _firestore.collection('users').doc(user.uid).delete();
          } catch (_) {
            // best effort
          }
          try {
            await user.delete();
          } catch (_) {
            // best effort
          }
          return SignUpResult(
            errorMessage:
                tokenError ?? 'Unable to initialize parent approval flow.',
          );
        }

        final childUid = user.uid;
        await _auth.signOut();
        _currentUser = null;
        return SignUpResult(
          requiresParentApproval: true,
          childUid: childUid,
          approvalToken: approvalToken,
          infoMessage:
              'Parent approval required. Pass the phone to a parent to finish setup.',
        );
      }

      _currentUser = _profileFromFirestore(
        {
          'name': normalizedName,
          'age': age,
          'approvalStatus': approvalStatus,
          'isBusinessAccount': isBusinessAccount,
        },
        fallbackName: normalizedName,
      );

      return const SignUpResult();
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'email-already-in-use':
          return const SignUpResult(
            errorMessage: 'An account already exists for this email.',
          );
        case 'invalid-email':
          return const SignUpResult(
            errorMessage: 'Please provide a valid email.',
          );
        case 'weak-password':
          return const SignUpResult(
            errorMessage: 'Password must be at least 6 characters.',
          );
        default:
          return SignUpResult(
            errorMessage: error.message ?? 'Unable to create account.',
          );
      }
    } on FirebaseException {
      return const SignUpResult(
        errorMessage: 'Unable to save account profile. Please try again.',
      );
    } catch (_) {
      return const SignUpResult(errorMessage: 'Unable to create account.');
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Unable to sign in.';
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final profileJson = doc.data() ?? <String, dynamic>{};
      final approvalStatus = (profileJson['approvalStatus'] as String?) ??
          (profileJson['age'] is num &&
                  (profileJson['age'] as num).toInt() >= 13 &&
                  (profileJson['age'] as num).toInt() <= 17
              ? 'pending'
              : 'approved');

      if (approvalStatus == 'pending') {
        await _auth.signOut();
        _currentUser = null;
        return 'Parent approval is still pending. Please check parent email.';
      }

      _currentUser = _profileFromFirestore(
        profileJson,
        fallbackName: user.email?.split('@').first ?? 'Giggo User',
      );
      return null;
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'invalid-email':
          return 'Please provide a valid email.';
        default:
          return error.message ?? 'Unable to sign in.';
      }
    } on FirebaseException {
      return 'Unable to load account profile.';
    } catch (_) {
      return 'Unable to sign in.';
    }
  }

  Future<String?> approveTeenAccount({
    required String approvalToken,
    required String parentEmail,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_approveTeenAccountUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'approvalToken': approvalToken.trim(),
          'parentEmail': parentEmail.trim().toLowerCase(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return (body['message'] as String?) ?? 'Unable to approve account.';
      }
      return 'Unable to approve account.';
    } catch (_) {
      return 'Unable to reach approval service.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  Future<String?> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (user == null || uid == null) {
      return 'Please log in before deleting your account.';
    }

    try {
      await _firestore.collection('users').doc(uid).set({
        'accountStatus': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'name': 'Deleted User',
        'bio': '',
        'providerSubscriptionActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _servicePagesCollection.doc(uid).set({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.delete();
      _currentUser = null;
      return null;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        return 'Please log out and sign in again before deleting your account.';
      }
      return error.message ?? 'Unable to delete account.';
    } catch (_) {
      return 'Unable to delete account. Please try again.';
    }
  }

  double get platformCommissionRate =>
      hasActiveProviderSubscription ? 0 : standardPlatformCommissionRate;

  Future<void> fetchGigs() async {
    try {
      final snapshot = await _gigsCollection.get();
      if (snapshot.docs.isNotEmpty) {
        _gigs
          ..clear()
          ..addAll(
            snapshot.docs
                .map(
                  (doc) => Gig.fromJson({
                    ...doc.data(),
                    'id': doc.id,
                  }),
                )
                .toList(),
          );
      }
    } catch (_) {
      // Keep fallback in-memory gigs when backend is not reachable.
    }
  }

  Future<Gig> addGig(Gig gig) async {
    try {
      final docRef = _gigsCollection.doc();
      final createdGig = Gig(
        id: docRef.id,
        title: gig.title,
        description: gig.description,
        category: gig.category,
        price: gig.price,
        providerName: gig.providerName,
        location: gig.location,
        providerUid: gig.providerUid ?? _auth.currentUser?.uid,
        minAge: gig.minAge,
        requiresBackgroundCheck: gig.requiresBackgroundCheck,
        isLateNight: gig.isLateNight,
        availableSlots: gig.availableSlots,
        imageUrls: gig.imageUrls,
        tags: gig.tags,
        isActive: gig.isActive,
      );

      await docRef.set({
        ...createdGig.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _gigs.insert(0, createdGig);
      return createdGig;
    } catch (_) {
      // Fall back below.
    }

    _gigs.insert(0, gig);
    return gig;
  }

  Future<Gig> updateGig(Gig gig) async {
    try {
      await _gigsCollection.doc(gig.id).set({
        ...gig.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Fall back to local state below.
    }

    final index = _gigs.indexWhere((item) => item.id == gig.id);
    if (index >= 0) {
      _gigs[index] = gig;
    } else {
      _gigs.insert(0, gig);
    }
    return gig;
  }

  Future<void> deleteGig(String gigId) async {
    try {
      await _gigsCollection.doc(gigId).delete();
      _gigs.removeWhere((gig) => gig.id == gigId);
    } catch (_) {
      _gigs.removeWhere((gig) => gig.id == gigId);
    }
  }

  double platformFeeFor(double amount) => amount * platformCommissionRate;

  double workerPayoutFor(double amount) => amount - platformFeeFor(amount);

  Future<void> fetchEscrows() async {
    try {
      final snapshot = await _escrowsCollection.get();
      if (snapshot.docs.isNotEmpty) {
        final loadedPayments = snapshot.docs
            .map(
              (doc) => EscrowPayment.fromJson({
                ...doc.data(),
                'id': doc.id,
              }),
            )
            .toList();

        loadedPayments.sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        _payments
          ..clear()
          ..addAll(loadedPayments);
      }
    } catch (_) {
      // Keep fallback in-memory escrows when backend is not reachable.
    }
  }

  Future<EscrowPayment> createEscrow({
    required String gigId,
    required double amount,
    String? serviceTitle,
    String? providerUid,
    String? clientUid,
  }) async {
    try {
      final docRef = _escrowsCollection.doc();
      final payment = EscrowPayment(
        id: docRef.id,
        gigId: gigId,
        amount: amount,
        status: EscrowStatus.pendingFunding,
        createdAt: DateTime.now().toUtc(),
        serviceTitle: serviceTitle,
        providerUid: providerUid,
        clientUid: clientUid,
      );

      await docRef.set({
        ...payment.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _payments.insert(0, payment);
      return payment;
    } catch (_) {
      // Fall back below.
    }

    final payment = EscrowPayment(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      gigId: gigId,
      amount: amount,
      status: EscrowStatus.pendingFunding,
      createdAt: DateTime.now().toUtc(),
      serviceTitle: serviceTitle,
      providerUid: providerUid,
      clientUid: clientUid,
    );

    _payments.insert(0, payment);
    return payment;
  }

  Future<void> fundEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      await _escrowsCollection.doc(escrowId).update({'status': 'funded'});
      payment.status = EscrowStatus.funded;
      return;
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.funded;
  }

  Future<void> releaseEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      await _escrowsCollection.doc(escrowId).update({'status': 'released'});
      payment.status = EscrowStatus.released;
      return;
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.released;
  }

  Future<void> disputeEscrow(String escrowId) async {
    final payment = _payments.firstWhere((p) => p.id == escrowId);
    try {
      await _escrowsCollection.doc(escrowId).update({'status': 'disputed'});
      payment.status = EscrowStatus.disputed;
      return;
    } catch (_) {
      // Fall back below.
    }

    payment.status = EscrowStatus.disputed;
  }
}
