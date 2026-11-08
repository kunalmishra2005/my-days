import 'dart:convert';

import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GuidelinesStorage {
  Future<BrandGuidelines> load();

  Future<void> save(BrandGuidelines guidelines);
}

class SharedPreferencesGuidelinesStorage implements GuidelinesStorage {
  const SharedPreferencesGuidelinesStorage();

  static const _storageKey = 'brand_governance.guidelines.v1';

  @override
  Future<BrandGuidelines> load() async {
    final preferences = await SharedPreferences.getInstance();
    final storedJson = preferences.getString(_storageKey);
    if (storedJson == null) return const BrandGuidelines();

    final decoded = jsonDecode(storedJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved brand guidelines are not an object.');
    }
    return BrandGuidelines.fromJson(decoded);
  }

  @override
  Future<void> save(BrandGuidelines guidelines) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(guidelines.toJson()),
    );
    if (!saved) {
      throw StateError('Brand guidelines could not be saved locally.');
    }
  }
}
