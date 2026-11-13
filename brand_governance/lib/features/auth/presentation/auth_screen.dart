import 'package:flutter/material.dart';

import '../data/supabase_auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    this.onDemoAccess,
    this.demoOnly = false,
  });

  final AuthenticationService authService;
  final VoidCallback? onDemoAccess;
  final bool demoOnly;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      String successMessage;
      if (_isLogin) {
        await widget.authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        successMessage = 'Signed in successfully.';
      } else {
        final result = await widget.authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        successMessage = switch (result) {
          SignUpResult.signedIn =>
            'Account created and signed in successfully.',
          SignUpResult.emailConfirmationRequired => 'Account created. Check your email and confirm your address before signing in.',
        };
      }

      if (!mounted) return;

      setState(() {
        _message = successMessage;
        _isError = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _message = error.toString().replaceFirst('Exception: ', '');
        _isError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 52,
                      color: Color(0xFF6C5CE7),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "MY DAY'S",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Brand governance workspace',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 36),

                    if (widget.demoOnly) ...[
                      Text(
                        'Judge sample workspace',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Explore fictional sample guidelines, submissions, '
                        'analysis and a human review. Demo data stays in this '
                        'browser and does not connect to Supabase.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('enterJudgeDemoButton'),
                        onPressed: _isLoading ? null : widget.onDemoAccess,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Explore sample workspace'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Local demo only · No account or credentials are '
                        'created. Sign out to return here.',
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        _isLogin ? 'Welcome back' : 'Create your account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _isLogin
                            ? 'Sign in to manage your brand workspace.'
                            : 'Create an account to get started.',
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            return 'Enter a valid email address.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_isLoading) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.length < 6) {
                            return 'Password must contain at least 6 characters.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      if (_message != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isError
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _isError
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_isLogin ? 'Sign In' : 'Create Account'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isLogin = !_isLogin;
                                  _message = null;
                                  _formKey.currentState?.reset();
                                });
                              },
                        child: Text(
                          _isLogin
                              ? "Don't have an account? Create one"
                              : 'Already have an account? Sign in',
                        ),
                      ),
                      if (widget.onDemoAccess != null) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        TextButton.icon(
                          key: const Key('enterJudgeDemoButton'),
                          onPressed: _isLoading ? null : widget.onDemoAccess,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Explore local sample workspace'),
                        ),
                        const Text(
                          'Fictional data stored locally; no Supabase account '
                          'or cloud access is used in demo mode.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
