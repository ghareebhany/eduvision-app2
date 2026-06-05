import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  AppPalette — EduVision Unified Color Palette
///  مصدر الألوان الموحّد للتطبيق بأكمله
///
///   sage   #C9CBA3 — خلفيات فاتحة، borders
///   peach  #FFE1A8 — chips، highlights، accents
///   coral  #E26D5C — اللون الرئيسي، CTAs، progress
///   plum   #723D46 — ثانوي، gradients، headers
///   mocha  #472D30 — نصوص، header داكن
/// ══════════════════════════════════════════════════════════════════════════════
abstract class AppPalette {
  AppPalette._();

  // ── Core five ──────────────────────────────────────────────────────────────
  static const Color sage  = Color(0xFFC9CBA3);
  static const Color peach = Color(0xFFFFE1A8);
  static const Color coral = Color(0xFFE26D5C);
  static const Color plum  = Color(0xFF723D46);
  static const Color mocha = Color(0xFF472D30);

  // ── Derived / helpers ──────────────────────────────────────────────────────
  static const Color sageLight  = Color(0xFFECEEE0); // scaffold background
  static const Color coralLight = Color(0x1FE26D5C); // coral @ 12%
  static const Color mochaLight = Color(0x14472D30); // mocha @ 8%
  static const Color successGreen      = Color(0xFF3A7D5A);
  static const Color successGreenLight = Color(0x173A7D5A);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [mocha, plum],
  );

  static const LinearGradient btnGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end:   Alignment.centerRight,
    colors: [coral, plum],
  );

  static const LinearGradient progressGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end:   Alignment.centerRight,
    colors: [coral, plum],
  );

  // ── Thumbnail gradients (course cards) ────────────────────────────────────
  static const List<List<Color>> thumbGradients = [
    [mocha, plum],
    [plum, Color(0xFF9B4F5A)],
    [Color(0xFF3A7D5A), Color(0xFF2D6347)],
    [coral, plum],
    [Color(0xFF5A4A7A), Color(0xFF3D3360)],
    [Color(0xFF7A5A3A), Color(0xFF5A3D22)],
  ];
}
