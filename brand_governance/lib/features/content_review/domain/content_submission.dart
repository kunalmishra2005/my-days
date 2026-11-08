import 'dart:math';

enum ContentType {
  socialMedia,
  advertisement,
  email,
  blog;

  String get label => switch (this) {
    ContentType.socialMedia => 'Social Media',
    ContentType.advertisement => 'Advertisement',
    ContentType.email => 'Email',
    ContentType.blog => 'Blog',
  };
}

class ContentSubmission {
  const ContentSubmission({
    required this.id,
    required this.title,
    required this.type,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final ContentType type;
  final String body;
  final DateTime createdAt;

  factory ContentSubmission.create({
    required String title,
    required ContentType type,
    required String body,
    DateTime? createdAt,
  }) {
    return ContentSubmission(
      id: _generateId(),
      title: title.trim(),
      type: type,
      body: body,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory ContentSubmission.fromJson(Map<String, Object?> json) {
    return ContentSubmission(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      type: ContentType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () =>
            throw FormatException('Unknown content type "${json['type']}".'),
      ),
      body: _readString(json, 'body'),
      createdAt: DateTime.parse(_readString(json, 'createdAt')).toUtc(),
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Expected "$key" to be a string.');
  }

  static String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
