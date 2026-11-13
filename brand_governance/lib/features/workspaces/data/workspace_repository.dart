import 'package:brand_governance/core/data/supabase_data_gateway.dart';

class Workspace {
  const Workspace({required this.id, required this.name});

  final String id;
  final String name;
}

abstract interface class WorkspaceRepository {
  Future<Workspace> resolveCurrentWorkspace();
}

class WorkspaceProvisioningBlockedException implements Exception {
  const WorkspaceProvisioningBlockedException();

  @override
  String toString() =>
      'No workspace membership exists. Safe provisioning requires an '
      'approved atomic database operation; the client did not create a workspace.';
}

class SupabaseWorkspaceRepository implements WorkspaceRepository {
  const SupabaseWorkspaceRepository(this.gateway);

  final SupabaseDataGateway gateway;

  @override
  Future<Workspace> resolveCurrentWorkspace() async {
    final userId = gateway.authenticatedUserId;
    if (userId == null) {
      throw StateError('An authenticated session is required.');
    }

    final memberships = await gateway.select(
      'workspace_members',
      equals: {'user_id': userId},
    );
    if (memberships.isEmpty) {
      throw const WorkspaceProvisioningBlockedException();
    }
    if (memberships.length != 1) {
      throw StateError(
        'Multiple workspace memberships exist; an active workspace cannot '
        'be selected safely.',
      );
    }

    final workspaceId = memberships.single['workspace_id'];
    if (workspaceId is! String || workspaceId.isEmpty) {
      throw const FormatException(
        'Workspace membership has no valid workspace ID.',
      );
    }
    final workspaces = await gateway.select(
      'workspaces',
      equals: {'id': workspaceId},
    );
    if (workspaces.length != 1) {
      throw StateError(
        'The workspace membership could not be verified against an accessible '
        'workspace.',
      );
    }
    final name = workspaces.single['name'];
    if (name is! String) {
      throw const FormatException('Workspace has no valid name.');
    }
    return Workspace(id: workspaceId, name: name);
  }
}
