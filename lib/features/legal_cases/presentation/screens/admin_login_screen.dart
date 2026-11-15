import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/app_backend.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/auth_error_text.dart';
import '../../../../core/injection_container.dart';
import 'admin_hub_screen.dart';
import 'categories_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      final backend = sl<AppBackendRegistry>();
      await backend.signInAsAdmin(
        environment: backend.defaultEnvironment,
        email: email,
        password: password,
      );

      if (!mounted) return;
      // The back stack may hold reader screens; replace it so pressing back
      // from the hub never lands on a page whose admin menu is now open.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminHubScreen()),
        (route) => route.isFirst,
      );
    } on AdminAuthorizationException {
      if (mounted) {
        _showErrorSnackBar('هذا الحساب غير مخوّل بدور مسؤول في هذه البيئة');
      }
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorSnackBar(AuthErrorText.forException(e));
      }
    } on StateError {
      if (mounted) {
        _showErrorSnackBar('تسجيل الدخول غير متاح في هذه النسخة.');
      }
    } catch (_) {
      // Never render the raw exception: it can contain endpoint details.
      if (mounted) {
        _showErrorSnackBar(
          'تعذّر تسجيل الدخول. تحقّق من الاتصال وحاول مجددًا.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      await sl<AppBackendRegistry>().signOut();
    } catch (_) {
      // Signing out must never block the user; the local session is already
      // gone once Supabase drops it, and a retry can only be attempted after
      // the network returns anyway.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
      (route) => false,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => rebuildWithAppTheme(_buildScreen);

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'بوابة تسجيل دخول المشرف',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'العودة إلى المحتوى',
            onPressed: _isLoading
                ? null
                : () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚠️ هذه الصفحة مخصصة لمشرفي التطبيق فقط',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lock icon header
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(
                            0xFF38BDF8,
                          ).withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 42,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'منطقة مخصصة للإدارة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يرجى إدخال بيانات المشرف المصرح له للمتابعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Admin Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني للإدارة',
                            hintText: 'admin@example.com',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال البريد الإلكتروني';
                            }
                            if (!value.contains('@')) {
                              return 'يرجى إدخال بريد إلكتروني صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال كلمة المرور';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Every attempt starts from a clean session: a stale
                        // token from an earlier sign-in must never be reused.
                        TextButton.icon(
                          onPressed: _isLoading ? null : _handleSignOut,
                          icon: const Icon(Icons.link_off_rounded, size: 18),
                          label: const Text(
                            'إلغاء الجلسة الحالية والعودة للمحتوى',
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login Action Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleAdminLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
