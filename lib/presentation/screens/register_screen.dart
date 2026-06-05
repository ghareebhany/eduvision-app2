import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await DioClient.instance.dio.post(
        '/wp/v2/users',
        data: {
          'username': _emailCtrl.text.trim().split('@').first,
          'email':    _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'name':     _nameCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء الحساب بنجاح. يمكنك تسجيل الدخول الآن.',
                style: TextStyle()),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ?? 'فشل إنشاء الحساب';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب',
            style: TextStyle()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_nameCtrl, 'الاسم الكامل', Icons.person_outline,
                    validator: (v) =>
                        v!.trim().isEmpty ? 'يرجى إدخال اسمك' : null),
                const SizedBox(height: 16),
                _field(_emailCtrl, 'البريد الإلكتروني',
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        !v!.contains('@') ? 'بريد إلكتروني غير صحيح' : null),
                const SizedBox(height: 16),
                _passwordField(_passwordCtrl, 'كلمة المرور', _obscure1,
                    () => setState(() => _obscure1 = !_obscure1),
                    validator: (v) => v!.length < 8
                        ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
                        : null),
                const SizedBox(height: 16),
                _passwordField(
                    _confirmCtrl, 'تأكيد كلمة المرور', _obscure2,
                    () => setState(() => _obscure2 = !_obscure2),
                    validator: (v) => v != _passwordCtrl.text
                        ? 'كلمتا المرور غير متطابقتين'
                        : null),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('إنشاء الحساب',
                          style: TextStyle(
                              fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      decoration: _decor(label, icon),
      validator: validator,
    );
  }

  Widget _passwordField(TextEditingController ctrl, String label,
      bool obscure, VoidCallback toggle,
      {String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      textDirection: TextDirection.ltr,
      decoration: _decor(label, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: toggle,
        ),
      ),
      validator: validator,
    );
  }

  InputDecoration _decor(String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(),
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      filled: true,
      // FIX: surfaceVariant → surfaceContainerHighest
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
    );
  }
}
