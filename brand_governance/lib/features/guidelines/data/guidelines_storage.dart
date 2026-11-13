import 'dart:convert';

import 'package:brand_governance/core/data/account_storage_key.dart';
import 'package:brand_governance/core/data/supabase_data_gateway.dart';
import 'package:brand_governance/features/guidelines/domain/brand_guidelines.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GuidelinesStorage {
  Future<BrandGuidelines> load();

  Future<void> save(BrandGuidelines guidelines);
}

class SharedPreferencesGuidelinesStorage implements GuidelinesStorage {
  const SharedPreferencesGuidelinesStorage({this.userId})
    : assert(userId == null || userId != '');

  final String? userId;

  static const _legacyStorageKey = 'brand_governance.guidelines.v1';
  String get _storageKey => accountScopedStorageKey(_legacyStorageKey, userId);

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

class SupabaseGuidelinesStorage
    implements GuidelinesStorage, CloudBackedStorage {
  const SupabaseGuidelinesStorage({
    required this.gateway,
    required this.workspaceId,
  });

  final SupabaseDataGateway gateway;
  final String workspaceId;

  @override
  Future<BrandGuidelines> load() async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final rows = await gateway.select(
      'brand_guidelines',
      equals: {'workspace_id': workspaceId},
    );
    if (rows.isEmpty) return const BrandGuidelines();
    if (rows.length != 1) {
      throw StateError(
        'Multiple guideline rows exist for this workspace. Resolve the '
        'duplicate records before editing; workspace_id is not unique.',
      );
    }

    final json = rows.single['guidelines'];
    if (json is! Map) {
      throw const FormatException('Cloud guidelines JSON is not an object.');
    }
    return BrandGuidelines.fromJson(Map<String, Object?>.from(json));
  }

  @override
  Future<void> save(BrandGuidelines guidelines) async {
    await verifyWorkspaceMembership(gateway, workspaceId);
    final rows = await gateway.select(
      'brand_guidelines',
      equals: {'workspace_id': workspaceId},
    );
    if (rows.isEmpty) {
      throw StateError(
        'Guidelines cannot be created safely because the database has no '
        'unique workspace_id constraint or atomic create operation.',
      );
    }
    if (rows.length != 1) {
      throw StateError(
        'Guidelines cannot be saved while multiple workspace rows exist.',
      );
    }
    final id = rows.single['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Cloud guideline row has no valid ID.');
    }
    await gateway.update(
      'brand_guidelines',
      idColumn: 'id',
      id: id,
      values: {
        'workspace_id': workspaceId,
        'brand_name': guidelines.brandName,
        'guidelines': guidelines.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}
