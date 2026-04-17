import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  // Quick-fill buttons for demo accounts
  static const _demoAccounts = [
    ('GC', 'gc@demo.com'),
    ('Electrician', 'electrician@demo.com'),
    ('Plumber', 'plumber@demo.com'),
    ('Manager', 'manager@demo.com'),
    ('Admin', 'admin@demo.com'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref
          .read(authNotifierProvider.notifier)
          .signIn(_emailCtrl.text.trim(), _passwordCtrl.text);

      if (!mounted) return;

      setState(() => _loading = false);
      _navigateForRole(user.role);
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e);
        _loading = false;
      });
    }
  }

  void _navigateForRole(UserRole role) {
    final path = switch (role) {
      UserRole.worker => '/worker',
      UserRole.gc => '/gc',
      UserRole.manager => '/manager',
      UserRole.admin => '/admin',
    };
    context.go(path);
  }

  String _friendlyError(Object e) {
    if (e is AuthException) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid') &&
          (m.contains('credential') || m.contains('login'))) {
        return 'Incorrect email or password.';
      }
      if (m.contains('email') && m.contains('confirm')) {
        return 'Confirm your email in Supabase (Authentication) before signing in.';
      }
      return e.message;
    }

    final raw = e.toString().toLowerCase();
    if (raw.contains('wrong-password') ||
        raw.contains('invalid_login_credentials') ||
        raw.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('user-not-found')) {
      return 'No account found with that email.';
    }
    if (raw.contains('profile not found')) {
      return 'Profile row missing or blocked by RLS. Ensure app_users.id matches your auth user UUID '
          'and run the migration that adds `authenticated` RLS policies.';
    }
    if (raw.contains('network') || raw.contains('socketexception')) {
      return 'Network error. Check your internet connection.';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BVColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),

              // ── Logo / Brand ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BVColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.construction,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BuildVox',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: BVColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Construction site communication,\nsimplified.',
                style: TextStyle(
                  fontSize: 15,
                  color: BVColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // ── Sign-in form ───────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: BVColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: BVColors.textSecondary,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BVColors.blocker.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: BVColors.blocker.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: BVColors.blocker, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: BVColors.blocker,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign-in button
                    ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Sign In'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Demo account quick-fill ────────────────────────────────────
              const Text(
                'DEMO ACCOUNTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BVColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Password for all: BuildVox2024!',
                style: TextStyle(
                  fontSize: 12,
                  color: BVColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _demoAccounts.map((account) {
                  return OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            _emailCtrl.text = account.$2;
                            _passwordCtrl.text = 'BuildVox2024!';
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                    ),
                    child: Text(account.$1, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
