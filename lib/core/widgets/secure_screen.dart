import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// يمنع تصوير الشاشة والـ screenshot على Android و iOS
/// يُغلّف شاشات الفيديو والـ quiz
class SecureScreen extends StatefulWidget {
  final Widget child;
  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.eduvision3.app/secure');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSecure(true);
  }

  @override
  void dispose() {
    _setSecure(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // إعادة تفعيل الحماية عند العودة للتطبيق
    if (state == AppLifecycleState.resumed) {
      _setSecure(true);
    }
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
    } catch (_) {
      // plugin not available — no-op
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
