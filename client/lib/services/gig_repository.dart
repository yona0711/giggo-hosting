import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/escrow_payment.dart';
import '../models/gig.dart';
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

class GigRepository {
  GigRepository({
    http.Client? httpClient,
    this.baseUrl = 'http://localhost:4000',
  })  : _httpClient = httpClient ?? http.Client(),
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

  CollectionReference<Map<String, dynamic>> get _gigsCollection =>
      _firestore.collection('gigs');
  CollectionReference<Map<String, dynamic>> get _escrowsCollection =>
      _firestore.collection('escrows');

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
        errorMessage: 'Parent email is required for ages 13–17.',
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
              'Parent approval required. Share the approval token with your parent.',
        );
      }

      _currentUser = _profileFromFirestore(
        {
          'name': normalizedName,
          'age': age,
          'approvalStatus': approvalStatus,
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

  double get platformCommissionRate => 0.15;

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
        minAge: gig.minAge,
        requiresBackgroundCheck: gig.requiresBackgroundCheck,
        isLateNight: gig.isLateNight,
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

  double platformFeeFor(double amount) => amount * platformCommissionRate;

  double workerPayoutFor(double amount) => amount - platformFeeFor(amount);

  Future<void> fetchEscrows() async {
    try {
      final snapshot = await _escrowsCollection.get();
      if (snapshot.docs.isNotEmpty) {
        _payments
          ..clear()
          ..addAll(
            snapshot.docs
                .map(
                  (doc) => EscrowPayment.fromJson({
                    ...doc.data(),
                    'id': doc.id,
                  }),
                )
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
      final docRef = _escrowsCollection.doc();
      final payment = EscrowPayment(
        id: docRef.id,
        gigId: gigId,
        amount: amount,
        status: EscrowStatus.pendingFunding,
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
