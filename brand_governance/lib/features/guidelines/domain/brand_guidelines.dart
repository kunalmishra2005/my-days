enum BrandTone {
  professional,
  friendly,
  formal,
  conversational,
  custom;

  String get label => switch (this) {
    BrandTone.professional => 'Professional',
    BrandTone.friendly => 'Friendly',
    BrandTone.formal => 'Formal',
    BrandTone.conversational => 'Conversational',
    BrandTone.custom => 'Custom',
  };
}

class BrandGuidelines {
  const BrandGuidelines({
    this.brandName = '',
    this.description = '',
    this.tone = BrandTone.professional,
    this.customTone = '',
    this.approvedTerms = const [],
    this.requiredTerms = const [],
    this.prohibitedTerms = const [],
    this.verifiedFacts = const [],
  });

  final String brandName;
  final String description;
  final BrandTone tone;
  final String customTone;
  final List<String> approvedTerms;
  final List<String> requiredTerms;
  final List<String> prohibitedTerms;
  final List<String> verifiedFacts;

  BrandGuidelines copyWith({
    String? brandName,
    String? description,
    BrandTone? tone,
    String? customTone,
    List<String>? approvedTerms,
    List<String>? requiredTerms,
    List<String>? prohibitedTerms,
    List<String>? verifiedFacts,
  }) {
    return BrandGuidelines(
      brandName: brandName ?? this.brandName,
      description: description ?? this.description,
      tone: tone ?? this.tone,
      customTone: customTone ?? this.customTone,
      approvedTerms: approvedTerms ?? this.approvedTerms,
      requiredTerms: requiredTerms ?? this.requiredTerms,
      prohibitedTerms: prohibitedTerms ?? this.prohibitedTerms,
      verifiedFacts: verifiedFacts ?? this.verifiedFacts,
    );
  }

  Map<String, Object?> toJson() => {
    'brandName': brandName,
    'description': description,
    'tone': tone.name,
    'customTone': customTone,
    'approvedTerms': approvedTerms,
    'requiredTerms': requiredTerms,
    'prohibitedTerms': prohibitedTerms,
    'verifiedFacts': verifiedFacts,
  };

  factory BrandGuidelines.fromJson(Map<String, Object?> json) {
    return BrandGuidelines(
      brandName: _readString(json, 'brandName'),
      description: _readString(json, 'description'),
      tone: BrandTone.values.firstWhere(
        (tone) => tone.name == json['tone'],
        orElse: () => BrandTone.professional,
      ),
      customTone: _readString(json, 'customTone'),
      approvedTerms: _readStringList(json, 'approvedTerms'),
      requiredTerms: _readStringList(json, 'requiredTerms'),
      prohibitedTerms: _readStringList(json, 'prohibitedTerms'),
      verifiedFacts: _readStringList(json, 'verifiedFacts'),
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string.');
  }

  static List<String> _readStringList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is List<Object?> && value.every((item) => item is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw FormatException('Expected "$key" to be a list of strings.');
  }
}
