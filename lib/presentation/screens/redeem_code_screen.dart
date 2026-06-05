import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../providers/bundles_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum RedeemStatus { idle, loading, success, error }

class RedeemState {
  final RedeemStatus            status;
  final String                  message;
  final Map<String, dynamic>?   result;

  const RedeemState({
    this.status  = RedeemStatus.idle,
    this.message = '',
    this.result,
  });

  RedeemState copyWith({
    RedeemStatus?          status,
    String?                message,
    Map<String, dynamic>?  result,
  }) => RedeemState(
    status:  status  ?? this.status,
    message: message ?? this.message,
    result:  result  ?? this.result,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class RedeemNotifier extends StateNotifier<RedeemState> {
  RedeemNotifier() : super(const RedeemState());

  Future<void> redeem(String code, {int contentId = 0}) async {
    if (code.trim().isEmpty) return;
    state = state.copyWith(status: RedeemStatus.loading, message: '');

    try {
      final response = await DioClient.instance.dio.post(
        ApiConstants.redeemBundleCodeEndpoint,
        data: {
          'code': code.trim(),
          if (contentId > 0) 'content_id': contentId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        status:  RedeemStatus.success,
        message: (data['data']?['message'] ?? data['message']) as String? ?? 'تم التسجيل بنجاح!',
        result:  data['data'] as Map<String, dynamic>? ?? data,
      );
    } catch (e) {
      String msg = 'حدث خطأ أثناء الاسترداد';
      final str = e.toString();
      // استخرج رسالة الخطأ من الـ response مباشرة إذا وُجدت
      try {
        final resp = (e as dynamic).response;
        if (resp != null) {
          final body = resp.data as Map<String, dynamic>?;
          final serverMsg = body?['message'] as String?
              ?? body?['data']?['message'] as String?;
          if (serverMsg != null && serverMsg.isNotEmpty) {
            msg = serverMsg;
          }
        }
      } catch (_) {}
      if (msg == 'حدث خطأ أثناء الاسترداد') {
        if (str.contains('404')) msg = 'الكود غير موجود أو منتهي الصلاحية';
        if (str.contains('409')) msg = 'تم استخدام هذا الكود مسبقاً';
        if (str.contains('410')) msg = 'انتهت صلاحية هذا الكود';
        if (str.contains('401')) msg = 'يجب تسجيل الدخول أولاً';
        if (str.contains('422')) msg = 'لم يتم تحديد المحتوى المرتبط بهذا الكود';
        if (str.contains('503')) msg = 'نظام الأكواد غير مفعّل على هذه المنصة';
      }
      state = state.copyWith(status: RedeemStatus.error, message: msg);
    }
  }

  void reset() => state = const RedeemState();
}

final redeemProvider =
    StateNotifierProvider.autoDispose<RedeemNotifier, RedeemState>(
  (_) => RedeemNotifier(),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class RedeemCodeScreen extends ConsumerStatefulWidget {
  /// يُمرَّر عبر GoRouter extra:
  /// {
  ///   'bundle_id':    int    — ID الحزمة (0 إذا كان كورس فردي)
  ///   'bundle_title': String — اسم الحزمة
  ///   'content_type': String — 'bundle' | 'course'
  ///   'course_id':    int    — ID الكورس الفردي (0 إذا كانت حزمة)
  ///   'course_title': String — اسم الكورس الفردي
  /// }
  final Map<String, dynamic>? params;

  const RedeemCodeScreen({super.key, this.params});

  @override
  ConsumerState<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends ConsumerState<RedeemCodeScreen> {
  final _codeCtrl  = TextEditingController();
  final _focusNode = FocusNode();

  // مستخرجة من الـ params
  late final int    _bundleId;
  late final int    _courseId;
  late final String _contentType;  // 'bundle' | 'course'
  late final String _contextTitle; // اسم الحزمة أو الكورس
  late final bool   _isBundle;

  @override
  void initState() {
    super.initState();
    final p = widget.params ?? {};
    _bundleId    = (p['bundle_id']    as int?)    ?? 0;
    _courseId    = (p['course_id']    as int?)    ?? 0;
    _contentType = (p['content_type'] as String?) ?? 'bundle';
    _isBundle    = _contentType == 'bundle';
    _contextTitle = _isBundle
        ? ((p['bundle_title'] as String?)    ?? '')
        : ((p['course_title'] as String?)    ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    final contentId = _isBundle ? _bundleId : _courseId;
    await ref.read(redeemProvider.notifier).redeem(code, contentId: contentId);
  }

  /// بعد نجاح الكود: حدّث bundlesProvider محلياً بدون re-fetch
  void _onSuccess(Map<String, dynamic> result) {
    final type = result['type'] as String? ?? '';
    if (type == 'bundle') {
      final bundleId = (result['bundle_id'] as int?) ?? _bundleId;
      final enrolled = (result['enrolled_courses'] as List<dynamic>? ?? [])
          .map((c) => (c as Map)['id'] as int)
          .toList();
      if (bundleId > 0) {
        ref.read(bundlesProvider.notifier).markEnrolled(bundleId, enrolled);
      }
    } else if (type == 'course') {
      final courseId = (result['course_id'] as int?) ?? _courseId;
      if (_bundleId > 0 && courseId > 0) {
        ref.read(bundlesProvider.notifier).markEnrolled(_bundleId, [courseId]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(redeemProvider);

    ref.listen<RedeemState>(redeemProvider, (_, next) {
      if (next.status == RedeemStatus.success && next.result != null) {
        _onSuccess(next.result!);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.sage100,
      appBar: AppBar(
        title: Text(
          _isBundle ? 'كود الحزمة' : 'كود الدورة',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.mocha500,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [

              // ── Context Banner ──────────────────────────────────────
              if (_contextTitle.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.mocha50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.mocha200),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.mocha100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isBundle
                            ? Icons.collections_bookmark_rounded
                            : Icons.menu_book_rounded,
                        color: AppTheme.mocha500, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isBundle ? 'للالتحاق بحزمة:' : 'للالتحاق بدورة:',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _contextTitle,
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppTheme.mocha700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),

              // ── Main Card ──────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve:  Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: state.status == RedeemStatus.success && state.result != null
                    ? _SuccessCard(
                        key:     const ValueKey('success'),
                        result:  state.result!,
                        isBundle: _isBundle,
                        onReset: () {
                          ref.read(redeemProvider.notifier).reset();
                          _codeCtrl.clear();
                        },
                        onGoToCourses: () {
                          ref.read(redeemProvider.notifier).reset();
                          context.go('/my-courses');
                        },
                      )
                    : _InputCard(
                        key:        const ValueKey('input'),
                        codeCtrl:   _codeCtrl,
                        focusNode:  _focusNode,
                        isLoading:  state.status == RedeemStatus.loading,
                        error:      state.status == RedeemStatus.error
                                        ? state.message
                                        : null,
                        isBundle:   _isBundle,
                        onSubmit:   _submit,
                      ),
              ),

              const SizedBox(height: 24),

              // ── Help note ──────────────────────────────────────────
              if (state.status != RedeemStatus.success)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: AppTheme.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isBundle
                              ? 'كود الحزمة يُسجّلك تلقائياً في جميع الدورات المضمّنة.'
                                  '\nإذا أردت الاشتراك في دورة بعينها فقط، اضغط عليها مباشرة في قائمة الحزمة.'
                              : 'هذا الكود خاص بالدورة المذكورة أعلاه فقط.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.warning.withValues(alpha: 0.85),
                              height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input Card ────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final TextEditingController codeCtrl;
  final FocusNode             focusNode;
  final bool                  isLoading;
  final String?               error;
  final bool                  isBundle;
  final VoidCallback          onSubmit;

  const _InputCard({
    super.key,
    required this.codeCtrl,
    required this.focusNode,
    required this.isLoading,
    required this.error,
    required this.isBundle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.sage300),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mocha500.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.mocha50,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.mocha200),
            ),
            child: Icon(
              isBundle
                  ? Icons.collections_bookmark_rounded
                  : Icons.vpn_key_rounded,
              size: 32, color: AppTheme.mocha500,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isBundle ? 'أدخل كود الحزمة' : 'أدخل كود الدورة',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: AppTheme.mocha700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBundle
                ? 'أدخل الكود الذي حصلت عليه من المعلم للالتحاق بالحزمة'
                : 'أدخل الكود الخاص بهذه الدورة',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Code field
          TextField(
            controller:   codeCtrl,
            focusNode:    focusNode,
            textAlign:    TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold,
              letterSpacing: 4, color: AppTheme.mocha700,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_]')),
              LengthLimitingTextInputFormatter(32),
              _UpperCaseFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX',
              hintStyle: const TextStyle(
                  fontSize: 22, letterSpacing: 4,
                  color: AppTheme.sage500),
              filled: true,
              fillColor: AppTheme.sage100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error != null ? AppTheme.error : AppTheme.sage300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error != null ? AppTheme.error : AppTheme.sage300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: error != null ? AppTheme.error : AppTheme.mocha500,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 16),
              // Paste button
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded,
                    color: AppTheme.textMuted, size: 20),
                tooltip: 'لصق',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    codeCtrl.text = data!.text!.trim().toUpperCase();
                  }
                },
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),

          // Error message
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: AppTheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.error)),
              ),
            ]),
          ],

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: isLoading ? null : AppTheme.buttonGradient,
                color: isLoading ? AppTheme.sage500 : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'تفعيل الكود',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success Card ──────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool                 isBundle;
  final VoidCallback         onReset;
  final VoidCallback         onGoToCourses;

  const _SuccessCard({
    super.key,
    required this.result,
    required this.isBundle,
    required this.onReset,
    required this.onGoToCourses,
  });

  @override
  Widget build(BuildContext context) {
    final enrolledCourses = (result['enrolled_courses'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [

          // ✔ Icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  AppTheme.successLight,
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 44),
          ),
          const SizedBox(height: 16),

          Text(
            isBundle ? 'تم الالتحاق بالحزمة!' : 'تم الالتحاق بالدورة!',
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              color: AppTheme.mocha700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result['message'] as String? ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.success),
          ),

          // enrolled courses list (bundle only)
          if (isBundle && enrolledCourses.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.sage50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.sage300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.library_books_rounded,
                        size: 15, color: AppTheme.mocha500),
                    const SizedBox(width: 8),
                    Text(
                      'الدورات المُضافة (${enrolledCourses.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13,
                        color: AppTheme.mocha700,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ...enrolledCourses.map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.check_rounded,
                            size: 14, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c['title'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textMid),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // CTA: اذهب إلى دوراتي
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FilledButton.icon(
                onPressed: onGoToCourses,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white),
                label: const Text('ابدأ التعلم الآن',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: redeem another
          OutlinedButton.icon(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.mocha500,
              side: const BorderSide(color: AppTheme.mocha200),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 11),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('استرداد كود آخر'),
          ),
        ],
      ),
    );
  }
}

// ── UpperCase Formatter ───────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue _, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
