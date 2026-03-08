class Gig {
  Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.providerName,
    required this.location,
    this.minAge = 13,
    this.requiresBackgroundCheck = false,
    this.isLateNight = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String providerName;
  final String location;
  final int minAge;
  final bool requiresBackgroundCheck;
  final bool isLateNight;

  factory Gig.fromJson(Map<String, dynamic> json) {
    return Gig(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      providerName: json['providerName'] as String,
      location: json['location'] as String,
      minAge: (json['minAge'] as num?)?.toInt() ?? 13,
      requiresBackgroundCheck:
          json['requiresBackgroundCheck'] as bool? ?? false,
      isLateNight: json['isLateNight'] as bool? ?? false,
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
      'minAge': minAge,
      'requiresBackgroundCheck': requiresBackgroundCheck,
      'isLateNight': isLateNight,
    };
  }
}
