import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _mainCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;
  
  late final Animation<double> _dotsAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    _logoFade = CurvedAnimation(parent: _mainCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn));
    
    _textSlide = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );
    _textFade = CurvedAnimation(parent: _mainCtrl,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn));

    _shimmerCtrl = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    
    _dotsAnimation = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );

    _mainCtrl.forward();

    ref.listenManual<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated ||
          next is AuthUnauthenticated ||
          next is AuthError) {
        _navigate(next);
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _hasNavigated) return;
      final s = ref.read(authProvider);
      if (s is AuthInitial || s is AuthLoading) {
        _navigate(const AuthUnauthenticated());
      }
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _navigate(AuthState next) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    if (next is AuthAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // ✅ تكبير حجم اللوجو بشكل كبير
    final logoSize = (size.width * 0.48).clamp(160.0, 240.0);
    final titleSize = (size.width * 0.12).clamp(38.0, 48.0);
    final subTitleSize = (size.width * 0.055).clamp(18.0, 24.0);
    final dotSize = (size.width * 0.025).clamp(12.0, 18.0);

    return Scaffold(
      backgroundColor: AppTheme.mocha900,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.splashGradient),
        child: Stack(children: [

          // ── Decorative circles أكثر فخامة ────────────────────────────
          Positioned(top: -size.width * 0.15, right: -size.width * 0.1,
            child: _DecorCircle(size: size.width * 0.5, opacity: 0.04)),
          Positioned(bottom: -size.width * 0.2, left: -size.width * 0.1,
            child: _DecorCircle(size: size.width * 0.6, opacity: 0.03)),
          Positioned(top: size.height * 0.3, left: -size.width * 0.2,
            child: _DecorCircle(size: size.width * 0.4, opacity: 0.025)),
          Positioned(bottom: size.height * 0.2, right: -size.width * 0.15,
            child: _DecorCircle(size: size.width * 0.35, opacity: 0.02)),

          // ── Hero Layout ─────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ✅ BLOCK 1: تكبير اللوجو وإضافة تأثيرات فاخرة
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // ✅ إطار فاخر مزدوج
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.coral500.withValues(alpha: 0.15),
                              AppTheme.mocha500.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: AppTheme.coral500.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.coral500.withValues(alpha: 0.15),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 0),
                            ),
                            BoxShadow(
                              color: AppTheme.coral500.withValues(alpha: 0.08),
                              blurRadius: 80,
                              spreadRadius: 20,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.coral500,
                                    AppTheme.mocha700,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 80,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ✅ BLOCK 2: نص "ايديو فيجن" بتصميم فاخر
                  FadeTransition(
                    opacity: _textFade,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Column(
                        children: [
                          Text(
                            'ايديو فيجن',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: AppTheme.coral500.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 2),
                                ),
                                Shadow(
                                  color: AppTheme.coral500.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ✅ نقطة زخرفية فاخرة
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.coral500,
                                  AppTheme.peach400,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.coral500.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // ✅ النص الجديد "#اتعلم_ازاي_تتعلم"
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  AppTheme.coral500.withValues(alpha: 0.1),
                                  AppTheme.mocha500.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: AppTheme.coral500.withValues(alpha: 0.15),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '#اتعلم_ازاي_تتعلم',
                              style: TextStyle(
                                color: AppTheme.peach400.withValues(alpha: 0.85),
                                fontSize: subTitleSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.coral500.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ✅ BLOCK 3: Status Block (نقاط متحركة أكبر)
                  FadeTransition(
                    opacity: _textFade,
                    child: Transform.translate(
                      offset: Offset(0, _textSlide.value * 0.6),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _dotsAnimation,
                            builder: (context, child) {
                              final t = _dotsAnimation.value;
                              final opacity1 = (0.25 + t).clamp(0.25, 1.0);
                              final opacity2 = (0.25 + (t - 0.33).abs() * 2).clamp(0.25, 1.0);
                              final opacity3 = (0.25 + (t - 0.66).abs() * 2).clamp(0.25, 1.0);
                              
                              return Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _LoadingDotOptimized(
                                        opacity: opacity1,
                                        dotSize: dotSize,
                                        isLarge: false,
                                      ),
                                      const SizedBox(width: 12),
                                      _LoadingDotOptimized(
                                        opacity: opacity2,
                                        dotSize: dotSize * 1.2,
                                        isLarge: true,
                                      ),
                                      const SizedBox(width: 12),
                                      _LoadingDotOptimized(
                                        opacity: opacity3,
                                        dotSize: dotSize,
                                        isLarge: false,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'جاري التحضير',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'EduVision Platform',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.06),
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

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
        width: 0.8,
      ),
    ),
  );
}

// ✅ نقطة تحميل بتصميم فاخر وأكبر حجماً
class _LoadingDotOptimized extends StatelessWidget {
  final double opacity;
  final double dotSize;
  final bool isLarge;

  const _LoadingDotOptimized({
    required this.opacity,
    required this.dotSize,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLarge
                ? [AppTheme.coral500, AppTheme.coral600]
                : [AppTheme.peach400, AppTheme.coral500],
          ),
          boxShadow: [
            BoxShadow(
              color: (isLarge ? AppTheme.coral500 : AppTheme.peach400).withValues(alpha: 0.4),
              blurRadius: dotSize * 0.6,
              spreadRadius: dotSize * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}
