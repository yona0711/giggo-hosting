class UserProfile {
  const UserProfile({
    required this.name,
    required this.age,
    required this.rating,
    required this.completedGigs,
    required this.bio,
    required this.isVerified,
    required this.backgroundChecked,
    required this.skills,
    this.hasParentMonitoring = false,
    this.parentPayoutApproval = false,
    this.payoutLimitPerWeek = 0,
    this.isBusinessAccount = false,
    this.providerSubscriptionActive = false,
    this.providerSubscriptionRenewsAt,
    this.parentEmail = '',
    this.approvalStatus = 'approved',
  });

  final String name;
  final int age;
  final double rating;
  final int completedGigs;
  final String bio;
  final bool isVerified;
  final bool backgroundChecked;
  final List<String> skills;
  final bool hasParentMonitoring;
  final bool parentPayoutApproval;
  final int payoutLimitPerWeek;
  final bool isBusinessAccount;
  final bool providerSubscriptionActive;
  final DateTime? providerSubscriptionRenewsAt;
  final String parentEmail;
  final String approvalStatus;

  bool get isTeen => age >= 13 && age <= 17;
  bool get requiresGuardianServiceApproval => isTeen;
  bool get guardianAccountApproved => !isTeen || approvalStatus == 'approved';
  String get ageBadge => isTeen ? '13-17' : '18+';

  UserProfile copyWith({
    String? name,
    int? age,
    double? rating,
    int? completedGigs,
    String? bio,
    bool? isVerified,
    bool? backgroundChecked,
    List<String>? skills,
    bool? hasParentMonitoring,
    bool? parentPayoutApproval,
    int? payoutLimitPerWeek,
    bool? isBusinessAccount,
    bool? providerSubscriptionActive,
    DateTime? providerSubscriptionRenewsAt,
    String? parentEmail,
    String? approvalStatus,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      rating: rating ?? this.rating,
      completedGigs: completedGigs ?? this.completedGigs,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      backgroundChecked: backgroundChecked ?? this.backgroundChecked,
      skills: skills ?? this.skills,
      hasParentMonitoring: hasParentMonitoring ?? this.hasParentMonitoring,
      parentPayoutApproval: parentPayoutApproval ?? this.parentPayoutApproval,
      payoutLimitPerWeek: payoutLimitPerWeek ?? this.payoutLimitPerWeek,
      isBusinessAccount: isBusinessAccount ?? this.isBusinessAccount,
      providerSubscriptionActive:
          providerSubscriptionActive ?? this.providerSubscriptionActive,
      providerSubscriptionRenewsAt:
          providerSubscriptionRenewsAt ?? this.providerSubscriptionRenewsAt,
      parentEmail: parentEmail ?? this.parentEmail,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  factory UserProfile.fromAuthPayload(Map<String, dynamic> json) {
    final parsedAge = (json['age'] as num?)?.toInt() ?? 18;
    final isTeen = parsedAge >= 13 && parsedAge <= 17;
    return UserProfile(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Giggo User',
      age: parsedAge,
      rating: 0,
      completedGigs: 0,
      bio: 'New to Giggo.',
      isVerified: false,
      backgroundChecked: false,
      skills: const ['Getting Started'],
      hasParentMonitoring: isTeen,
      parentPayoutApproval: isTeen,
      payoutLimitPerWeek: isTeen ? 250 : 0,
      isBusinessAccount: (json['isBusinessAccount'] as bool?) ?? false,
      providerSubscriptionActive:
          (json['providerSubscriptionActive'] as bool?) ?? false,
      parentEmail: (json['parentEmail'] as String?) ?? '',
      approvalStatus: (json['approvalStatus'] as String?) ?? 'approved',
    );
  }
}
