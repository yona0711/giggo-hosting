class ServicePage {
  const ServicePage({
    required this.ownerUid,
    required this.ownerName,
    required this.title,
    required this.about,
    required this.city,
    required this.categories,
    required this.imageUrls,
    required this.shareSlug,
    this.logoUrl = '',
    this.backgroundColor = '',
    this.backgroundImage = '',
    this.storefrontStyle = 'classic',
    this.heroHeadline = '',
    this.announcement = '',
    this.showCategoriesFirst = true,
    this.showTrustHighlights = true,
    this.listingLayout = 'cards',
    this.providerSubscriptionActive = false,
  });

  final String ownerUid;
  final String ownerName;
  final String title;
  final String about;
  final String city;
  final List<String> categories;
  final List<String> imageUrls;
  final String shareSlug;
  final String logoUrl;
  final String backgroundColor;
  final String backgroundImage;
  final String storefrontStyle;
  final String heroHeadline;
  final String announcement;
  final bool showCategoriesFirst;
  final bool showTrustHighlights;
  final String listingLayout;
  final bool providerSubscriptionActive;

  factory ServicePage.fromJson(Map<String, dynamic> json) {
    return ServicePage(
      ownerUid: (json['ownerUid'] as String?) ?? '',
      ownerName: (json['ownerName'] as String?) ?? 'Giggo Provider',
      title: (json['title'] as String?) ?? 'Local Services',
      about: (json['about'] as String?) ??
          'Reliable help for your neighborhood needs.',
      city: (json['city'] as String?) ?? '',
      categories: (json['categories'] as List?)
              ?.whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const <String>[],
      imageUrls: (json['imageUrls'] as List?)
              ?.whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toList() ??
          const <String>[],
      shareSlug: (json['shareSlug'] as String?) ?? '',
      logoUrl: (json['logoUrl'] as String?) ?? '',
      backgroundColor: (json['backgroundColor'] as String?) ?? '',
      backgroundImage: (json['backgroundImage'] as String?) ?? '',
      storefrontStyle: (json['storefrontStyle'] as String?) ?? 'classic',
      heroHeadline: (json['heroHeadline'] as String?) ?? '',
      announcement: (json['announcement'] as String?) ?? '',
      showCategoriesFirst: (json['showCategoriesFirst'] as bool?) ?? true,
      showTrustHighlights: (json['showTrustHighlights'] as bool?) ?? true,
      listingLayout: (json['listingLayout'] as String?) ?? 'cards',
      providerSubscriptionActive:
          (json['providerSubscriptionActive'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'title': title,
      'about': about,
      'city': city,
      'categories': categories,
      'imageUrls': imageUrls,
      'shareSlug': shareSlug,
      'logoUrl': logoUrl,
      'backgroundColor': backgroundColor,
      'backgroundImage': backgroundImage,
      'storefrontStyle': storefrontStyle,
      'heroHeadline': heroHeadline,
      'announcement': announcement,
      'showCategoriesFirst': showCategoriesFirst,
      'showTrustHighlights': showTrustHighlights,
      'listingLayout': listingLayout,
      'providerSubscriptionActive': providerSubscriptionActive,
    };
  }

  ServicePage copyWith({
    String? ownerUid,
    String? ownerName,
    String? title,
    String? about,
    String? city,
    List<String>? categories,
    List<String>? imageUrls,
    String? shareSlug,
    String? logoUrl,
    String? backgroundColor,
    String? backgroundImage,
    String? storefrontStyle,
    String? heroHeadline,
    String? announcement,
    bool? showCategoriesFirst,
    bool? showTrustHighlights,
    String? listingLayout,
    bool? providerSubscriptionActive,
  }) {
    return ServicePage(
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      title: title ?? this.title,
      about: about ?? this.about,
      city: city ?? this.city,
      categories: categories ?? this.categories,
      imageUrls: imageUrls ?? this.imageUrls,
      shareSlug: shareSlug ?? this.shareSlug,
      logoUrl: logoUrl ?? this.logoUrl,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      storefrontStyle: storefrontStyle ?? this.storefrontStyle,
      heroHeadline: heroHeadline ?? this.heroHeadline,
      announcement: announcement ?? this.announcement,
      showCategoriesFirst: showCategoriesFirst ?? this.showCategoriesFirst,
      showTrustHighlights: showTrustHighlights ?? this.showTrustHighlights,
      listingLayout: listingLayout ?? this.listingLayout,
      providerSubscriptionActive:
          providerSubscriptionActive ?? this.providerSubscriptionActive,
    );
  }
}
