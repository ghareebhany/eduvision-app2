import 'package:flutter/material.dart';

/// AppLogo — يعرض لوجو EduVision من assets.
/// - [size]: الحجم الكلي للويدجت (default 40)
/// - [circular]: هل يُعرض في إطار دائري (default false)
/// - [borderColor]: لون الإطار عند circular=true
/// - [padding]: padding داخل الإطار الدائري
class AppLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final Color? borderColor;
  final double padding;

  const AppLogo({
    super.key,
    this.size = 40,
    this.circular = false,
    this.borderColor,
    this.padding = 4,
  });

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/images/logo.png',
      width: circular ? size - padding * 2 : size,
      height: circular ? size - padding * 2 : size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackLogo(
        size: circular ? size - padding * 2 : size,
      ),
    );

    if (!circular) return img;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(padding),
      child: ClipOval(child: img),
    );
  }
}

/// FallbackLogo — يظهر عند فشل تحميل الصورة
class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const Icon(Icons.school_rounded, color: Colors.white),
    );
  }
}
