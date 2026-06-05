import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier)
        .login(_usernameCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final isLoading = ref.watch(authProvider) is AuthLoading;

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated) context.go('/home');
      if (next is AuthError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(next.message,
                  style: const TextStyle(color: Colors.white))),
            ]),
            backgroundColor: AppTheme.mocha700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: AppTheme.coral500,
              onPressed: () {},
            ),
          ));
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.mocha900,
      body: Container(
        // ── نفس splashGradient بالضبط ──────────────────────────────
        decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
        child: Stack(children: [

          // ── Decorative circles (مطابقة للـ splash) ─────────────────
          Positioned(
            top: -size.width * 0.15,
            right: -size.width * 0.1,
            child: _DecorCircle(size: size.width * 0.5, opacity: 0.02),
          ),
          Positioned(
            bottom: -size.width * 0.2,
            left: -size.width * 0.1,
            child: _DecorCircle(size: size.width * 0.6, opacity: 0.015),
          ),

          // ── Content ─────────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: SafeArea(
              top: false,
              child: CustomScrollView(slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(children: [

                    // ── Header Card (ملتصقة بالأعلى، عرض محدود) ────────
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.fromLTRB(24, 52, 24, 32),
                        decoration: BoxDecoration(
                          color: AppTheme.mocha800.withValues(alpha: 0.9),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(36),
                            bottomRight: Radius.circular(36),
                          ),
                          border: Border.all(
                            color: AppTheme.coral500.withValues(alpha: 0.12),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(children: [
                          // Logo
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.coral500.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                            ),
                            child: AppLogo(
                              size: 150,
                              circular: true,
                              borderColor: Colors.transparent,
                              padding: 6,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'ايديو فيجن',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '#اتعلم_ازاي_تتعلم',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 17,
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Form Card ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                              // Username
                              _FieldLabel(label: 'البريد الإلكتروني أو اسم المستخدم'),
                              const SizedBox(height: 8),
                              _DarkField(
                                controller: _usernameCtrl,
                                hint: 'example@email.com',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                              ),

                              const SizedBox(height: 16),

                              // Password
                              _FieldLabel(label: 'كلمة المرور'),
                              const SizedBox(height: 8),
                              _DarkField(
                                controller: _passwordCtrl,
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textDirection: TextDirection.ltr,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) =>
                                    (v == null || v.isEmpty)
                                        ? 'هذا الحقل مطلوب'
                                        : null,
                              ),

                              // Forgot password
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppTheme.coral500,
                                  ),
                                  child: const Text(
                                    'نسيت كلمة المرور؟',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Login button
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: isLoading
                                        ? null
                                        : AppTheme.buttonGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    color: isLoading
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : null,
                                    boxShadow: isLoading
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: AppTheme.coral500
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                  ),
                                  child: FilledButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text(
                                            'تسجيل الدخول',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Divider ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'أو',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 20),

                    // ── Register link ──────────────────────────────────
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.45)),
                          children: [
                            const TextSpan(text: 'ليس لديك حساب؟  '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => context.push('/register'),
                                child: const Text(
                                  'إنشاء حساب',
                                  style: TextStyle(
                                      color: AppTheme.coral500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // ── Footer ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'EduVision © ${DateTime.now().year}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.08),
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Dark-themed form field ────────────────────────────────────────────────────
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textDirection,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textDirection: textDirection,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.coral500, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.8), width: 1.5),
          ),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

// ── Field Label ───────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.65),
        ),
      );
}

// ── Decorative Circle (مطابق للـ splash) ─────────────────────────────────────
class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.coral500.withValues(alpha: opacity),
            width: 0.5,
          ),
        ),
      );
}
