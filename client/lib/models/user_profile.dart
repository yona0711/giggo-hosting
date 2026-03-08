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

  bool get isTeen => age >= 13 && age <= 17;
  String get ageBadge => isTeen ? '13–17' : '18+';

  factory UserProfile.fromAuthPayload(Map<String, dynamic> json) {
    final parsedAge = (json['age'] as num?)?.toInt() ?? 18;
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
      hasParentMonitoring: parsedAge >= 13 && parsedAge <= 17,
      parentPayoutApproval: parsedAge >= 13 && parsedAge <= 17,
      payoutLimitPerWeek: parsedAge >= 13 && parsedAge <= 17 ? 250 : 0,
    );
  }
}
