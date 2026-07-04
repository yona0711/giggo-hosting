class Gig {
  Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.providerName,
    required this.location,
    this.providerUid,
    this.minAge = 13,
    this.requiresBackgroundCheck = false,
    this.isLateNight = false,
    this.availableSlots = const [],
    this.imageUrls = const [],
    this.tags = const [],
    this.isActive = true,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String providerName;
  final String location;
  final String? providerUid;
  final int minAge;
  final bool requiresBackgroundCheck;
  final bool isLateNight;
  final List<DateTime> availableSlots;
  final List<String> imageUrls;
  final List<String> tags;
  final bool isActive;

  factory Gig.fromJson(Map<String, dynamic> json) {
    return Gig(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      providerName: json['providerName'] as String,
      location: json['location'] as String,
      providerUid: json['providerUid'] as String?,
      minAge: (json['minAge'] as num?)?.toInt() ?? 13,
      requiresBackgroundCheck:
          json['requiresBackgroundCheck'] as bool? ?? false,
      isLateNight: json['isLateNight'] as bool? ?? false,
      availableSlots: (json['availableSlots'] as List<dynamic>? ?? const [])
          .map((slot) => DateTime.tryParse(slot.toString()))
          .whereType<DateTime>()
          .toList(),
      imageUrls: (json['imageUrls'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      tags: (json['tags'] as List?)?.whereType<String>().toList() ??
          const <String>[],
      isActive: (json['isActive'] as bool?) ??
          ((json['status'] as String?) != 'paused' &&
              (json['status'] as String?) != 'deleted'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'providerName': providerName,
      'location': location,
      'providerUid': providerUid,
      'minAge': minAge,
      'requiresBackgroundCheck': requiresBackgroundCheck,
      'isLateNight': isLateNight,
      'availableSlots':
          availableSlots.map((slot) => slot.toIso8601String()).toList(),
      'imageUrls': imageUrls,
      'tags': tags,
      'isActive': isActive,
      'status': isActive ? 'active' : 'paused',
    };
  }

  Gig copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? price,
    String? providerName,
    String? location,
    String? providerUid,
    int? minAge,
    bool? requiresBackgroundCheck,
    bool? isLateNight,
    List<DateTime>? availableSlots,
    List<String>? imageUrls,
    List<String>? tags,
    bool? isActive,
  }) {
    return Gig(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      providerName: providerName ?? this.providerName,
      location: location ?? this.location,
      providerUid: providerUid ?? this.providerUid,
      minAge: minAge ?? this.minAge,
      requiresBackgroundCheck:
          requiresBackgroundCheck ?? this.requiresBackgroundCheck,
      isLateNight: isLateNight ?? this.isLateNight,
      availableSlots: availableSlots ?? this.availableSlots,
      imageUrls: imageUrls ?? this.imageUrls,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
    );
  }
}
