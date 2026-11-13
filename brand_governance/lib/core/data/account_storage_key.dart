import 'dart:convert';

String accountScopedStorageKey(String legacyKey, String? userId) {
  if (userId == null) return legacyKey;
  if (userId.isEmpty) {
    throw ArgumentError.value(userId, 'userId', 'Must not be empty.');
  }

  final encodedUserId = base64Url.encode(utf8.encode(userId));
  return '$legacyKey.account.$encodedUserId';
}
