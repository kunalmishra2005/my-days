import 'dart:async';

import 'package:brand_governance/features/auth/data/supabase_auth_service.dart';

class DemoAuthenticationService implements AuthenticationService {
  DemoAuthenticationService({this.cloudService}) {
    _cloudSubscription = cloudService?.authStateChanges.listen((user) {
      if (!_isDemo) _changes.add(user);
    }, onError: _changes.addError);
  }

  static const _demoUser = AuthenticatedUser(
    id: 'judge-demo-local-v1',
    email: 'Sample workspace · local only',
  );

  final StreamController<AuthenticatedUser?> _changes =
      StreamController<AuthenticatedUser?>.broadcast();
  final AuthenticationService? cloudService;
  late final StreamSubscription<AuthenticatedUser?>? _cloudSubscription;
  bool _isDemo = false;

  bool get isDemoMode => _isDemo;
  bool get hasCloudAuthentication => cloudService != null;
  AuthenticationService? get cloudAuthenticationService => cloudService;

  @override
  AuthenticatedUser? get currentUser =>
      _isDemo ? _demoUser : cloudService?.currentUser;

  @override
  Stream<AuthenticatedUser?> get authStateChanges => _changes.stream;

  void enterDemo() {
    _isDemo = true;
    _changes.add(_demoUser);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) {
    final service = cloudService;
    if (service != null) {
      return service.signUp(email: email, password: password);
    }
    throw StateError(
      'Cloud sign-up is unavailable in local demo mode. Configure Supabase '
      'to create an account.',
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    final service = cloudService;
    if (service != null) {
      return service.signIn(email: email, password: password);
    }
    throw StateError(
      'Cloud sign-in is unavailable in local demo mode. Configure Supabase '
      'to sign in.',
    );
  }

  @override
  Future<void> signOut() async {
    if (_isDemo) {
      _isDemo = false;
      _changes.add(cloudService?.currentUser);
      return;
    }
    final service = cloudService;
    if (service == null) {
      throw StateError(
        'There is no cloud account to sign out of in demo mode.',
      );
    }
    await service.signOut();
  }

  Future<void> dispose() async {
    await _cloudSubscription?.cancel();
    await _changes.close();
  }
}
