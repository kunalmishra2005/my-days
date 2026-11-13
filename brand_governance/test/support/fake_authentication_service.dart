import 'dart:async';

import 'package:brand_governance/features/auth/data/supabase_auth_service.dart';

class FakeAuthenticationService implements AuthenticationService {
  FakeAuthenticationService({
    AuthenticatedUser? initialUser = const AuthenticatedUser(
      id: 'test-user',
      email: 'test@example.com',
    ),
    this.signUpResult = SignUpResult.emailConfirmationRequired,
    this.signInError,
    this.signUpError,
    this.signOutError,
  }) : _currentUser = initialUser;

  final StreamController<AuthenticatedUser?> _authChanges =
      StreamController<AuthenticatedUser?>.broadcast(sync: true);
  final SignUpResult signUpResult;
  final Object? signInError;
  final Object? signUpError;
  final Object? signOutError;
  AuthenticatedUser? _currentUser;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Stream<AuthenticatedUser?> get authStateChanges => _authChanges.stream;

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final error = signUpError;
    if (error != null) throw error;
    if (signUpResult == SignUpResult.signedIn) {
      _setCurrentUser(AuthenticatedUser(id: 'created-user', email: email));
    }
    return signUpResult;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final error = signInError;
    if (error != null) throw error;
    _setCurrentUser(AuthenticatedUser(id: 'signed-in-user', email: email));
  }

  @override
  Future<void> signOut() async {
    final error = signOutError;
    if (error != null) throw error;
    _setCurrentUser(null);
  }

  Future<void> dispose() => _authChanges.close();

  void switchUser(AuthenticatedUser? user) => _setCurrentUser(user);

  void _setCurrentUser(AuthenticatedUser? user) {
    _currentUser = user;
    _authChanges.add(user);
  }
}
