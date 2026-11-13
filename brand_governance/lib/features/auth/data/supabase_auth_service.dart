import 'package:supabase_flutter/supabase_flutter.dart';

class AuthenticatedUser {
  const AuthenticatedUser({required this.id, this.email});

  final String id;
  final String? email;
}

enum SignUpResult { signedIn, emailConfirmationRequired }

abstract interface class AuthenticationService {
  AuthenticatedUser? get currentUser;

  Stream<AuthenticatedUser?> get authStateChanges;

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class SupabaseAuthService implements AuthenticationService {
  SupabaseAuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  @override
  AuthenticatedUser? get currentUser =>
      _toAuthenticatedUser(_client.auth.currentSession?.user);

  @override
  Stream<AuthenticatedUser?> get authStateChanges => _client
      .auth
      .onAuthStateChange
      .map((state) => _toAuthenticatedUser(state.session?.user));

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session == null
        ? SignUpResult.emailConfirmationRequired
        : SignUpResult.signedIn;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AuthenticatedUser? _toAuthenticatedUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(id: user.id, email: user.email);
  }
}
