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
    ('GC', 'gc@demo.com', Icons.construction_rounded),
    ('Electrician', 'electrician@demo.com', Icons.bolt_rounded),
    ('Plumber', 'plumber@demo.com', Icons.handyman_rounded),
    ('Manager', 'manager@demo.com', Icons.assignment_rounded),
    ('Admin', 'admin@demo.com', Icons.shield_rounded),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: BVColors.primary),
              const SizedBox(height: 56),

              // ── Logo / Brand ───────────────────────────────────────────────
              const _BlueprintBackdrop(),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: BVColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handyman, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BuildVox',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Construction site communication, simplified.',
                style: TextStyle(
                  fontSize: 14,
                  color: BVColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 44),

              // ── Sign-in form ───────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign in',
                      style: TextStyle(
                      fontSize: 22,
                        fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                        hintText: 'Email',
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
                        hintText: 'Password',
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Sign In'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Demo account quick-fill ────────────────────────────────────
              const _CenterDividerLabel(label: 'DEMO ACCOUNTS'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BVColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: BVColors.primary.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: BVColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Password for all: BuildVox2024!',
                      style: TextStyle(color: BVColors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _demoAccounts.map((account) {
                    final selected = _emailCtrl.text == account.$2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilterChip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        avatar: Icon(
                          account.$3,
                          size: 18,
                          color: selected ? BVColors.background : BVColors.primary,
                        ),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: BVColors.primary,
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(color: BVColors.primary),
                        ),
                        label: Text(
                          account.$1,
                          style: TextStyle(
                            color: selected ? BVColors.background : BVColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onSelected: _loading
                            ? null
                            : (_) {
                                setState(() {
                                  _emailCtrl.text = account.$2;
                                  _passwordCtrl.text = 'BuildVox2024!';
                                });
                              },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(color: BVColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterDividerLabel extends StatelessWidget {
  final String label;
  const _CenterDividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: BVColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: BVColors.textSecondary,
              letterSpacing: 1.2,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: BVColors.divider)),
      ],
    );
  }
}

class _BlueprintBackdrop extends StatelessWidget {
  const _BlueprintBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(double.infinity, 0),
        painter: _BlueprintPainter(),
      ),
    );
  }
}

class _BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BVColors.textSecondary.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = -200; x < 1000; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x + 300, 300), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
