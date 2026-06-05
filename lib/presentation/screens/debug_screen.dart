import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

/// Temporary debug screen to diagnose auth issues.
/// Access via: long-press on login button or navigate to /debug
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _log = 'جاهز للاختبار...';
  bool _loading = false;

  Future<void> _runDiagnostics() async {
    setState(() {
      _loading = true;
      _log = 'يجري الاختبار...\n';
    });

    final buffer = StringBuffer();

    // 1. Test JWT login
    buffer.writeln('══ 1. اختبار تسجيل الدخول ══');
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://eduvision3.com/wp-json',
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ));
      final loginRes = await dio.post(
        '/jwt-auth/v1/token',
        data: {
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      final body = loginRes.data as Map<String, dynamic>;
      final token = body['token'] as String? ?? '';
      buffer.writeln('✅ تسجيل الدخول نجح');
      buffer.writeln('   user_id: ${body['user_id']}');
      buffer.writeln('   user_email: ${body['user_email']}');
      buffer.writeln('   token (أول 30 حرف): ${token.length > 30 ? token.substring(0, 30) + '...' : token}');

      // 2. Validate token
      buffer.writeln('\n══ 2. التحقق من التوكن ══');
      try {
        final validateRes = await dio.post(
          '/jwt-auth/v1/token/validate',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        buffer.writeln('✅ التوكن صالح: ${validateRes.data}');
      } catch (e) {
        if (e is DioException) {
          buffer.writeln('❌ فشل التحقق: ${e.response?.statusCode}');
          buffer.writeln('   ${e.response?.data}');
        }
      }

      // 3. Test courses endpoint with token
      buffer.writeln('\n══ 3. اختبار API الكورسات ══');
      try {
        final coursesRes = await dio.get(
          '/tutor/v1/courses',
          queryParameters: {'per_page': 1},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        buffer.writeln('✅ الكورسات تعمل!');
        buffer.writeln('   status: ${coursesRes.statusCode}');
        final data = coursesRes.data;
        if (data is Map) {
          buffer.writeln('   keys: ${(data).keys.toList()}');
        }
      } catch (e) {
        if (e is DioException) {
          buffer.writeln('❌ فشل الكورسات: ${e.response?.statusCode}');
          buffer.writeln('   ${e.response?.data}');
        }
      }

      // 4. Test without token
      buffer.writeln('\n══ 4. اختبار بدون توكن ══');
      try {
        await dio.get('/tutor/v1/courses', queryParameters: {'per_page': 1});
        buffer.writeln('✅ يعمل بدون توكن (Public API)');
      } catch (e) {
        if (e is DioException) {
          buffer.writeln('ℹ️ بدون توكن: ${e.response?.statusCode} - ${e.response?.data?['code']}');
        }
      }

    } catch (e) {
      if (e is DioException) {
        buffer.writeln('❌ فشل تسجيل الدخول: ${e.response?.statusCode}');
        buffer.writeln('   ${e.response?.data}');
      } else {
        buffer.writeln('❌ خطأ: $e');
      }
    }

    setState(() {
      _log = buffer.toString();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شاشة التشخيص')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _runDiagnostics,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.bug_report),
              label: const Text('تشخيص'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: _log)),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ النتائج'),
            ),
          ],
        ),
      ),
    );
  }
}
