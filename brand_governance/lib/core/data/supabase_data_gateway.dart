import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class CloudBackedStorage {}

abstract interface class SupabaseDataGateway {
  String? get authenticatedUserId;

  Future<List<Map<String, Object?>>> select(
    String table, {
    Map<String, Object?> equals = const {},
    String? orderBy,
    bool ascending = true,
  });

  Future<void> insert(String table, Map<String, Object?> values);

  Future<void> update(
    String table, {
    required String idColumn,
    required String id,
    required Map<String, Object?> values,
  });
}

class AuthenticatedSupabaseDataGateway implements SupabaseDataGateway {
  const AuthenticatedSupabaseDataGateway(this.client);

  final SupabaseClient client;

  @override
  String? get authenticatedUserId => client.auth.currentUser?.id;

  @override
  Future<List<Map<String, Object?>>> select(
    String table, {
    Map<String, Object?> equals = const {},
    String? orderBy,
    bool ascending = true,
  }) async {
    final filters = <String, Object>{};
    for (final entry in equals.entries) {
      final value = entry.value;
      if (value == null) {
        throw ArgumentError.value(
          value,
          entry.key,
          'Filter values cannot be null.',
        );
      }
      filters[entry.key] = value;
    }
    final query = client.from(table).select().match(filters);
    final rows = orderBy == null
        ? await query
        : await query.order(orderBy, ascending: ascending);
    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<void> insert(String table, Map<String, Object?> values) async {
    await client.from(table).insert(values);
  }

  @override
  Future<void> update(
    String table, {
    required String idColumn,
    required String id,
    required Map<String, Object?> values,
  }) async {
    final updatedRows = await client
        .from(table)
        .update(values)
        .eq(idColumn, id)
        .select(idColumn);
    if (updatedRows.length != 1) {
      throw StateError(
        'The cloud update did not confirm exactly one updated row.',
      );
    }
  }
}

Future<void> verifyWorkspaceMembership(
  SupabaseDataGateway gateway,
  String workspaceId,
) async {
  final userId = gateway.authenticatedUserId;
  if (userId == null) {
    throw StateError('An authenticated session is required.');
  }

  final memberships = await gateway.select(
    'workspace_members',
    equals: {'workspace_id': workspaceId, 'user_id': userId},
  );
  if (memberships.isEmpty) {
    throw StateError(
      'The authenticated user is not a member of this workspace.',
    );
  }
}
