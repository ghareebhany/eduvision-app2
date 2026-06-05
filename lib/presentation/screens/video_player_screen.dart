import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/secure_storage.dart';
import '../../core/widgets/secure_screen.dart';
import '../../domain/entities/lesson.dart';
import '../providers/di_providers.dart';
import 'video_progress_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int courseId;
  final List<Lesson> allLessons;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.allLessons,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late Lesson _current;
  WebViewController? _webCtrl;
  bool _loading         = true;
  bool _hasError        = false;
  String _errorMsg      = '';
  bool _completionFired = false;

  @override
  void initState() {
    super.initState();
    _current = widget.lesson;
    _loadLesson(_current);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Load Lesson ───────────────────────────────────────────────────────────

  Future<void> _loadLesson(Lesson lesson) async {
    setState(() {
      _loading         = true;
      _hasError        = false;
      _completionFired = false;
      _webCtrl         = null;
    });

    final token = await SecureStorageService.instance.getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMsg = 'يرجى تسجيل الدخول مجدداً';
        _loading  = false;
      });
      return;
    }

    final url = ApiConstants.lessonViewUrl(lesson.id);

    late final WebViewController ctrl;
    ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (pageUrl) {
          if (true) {
            ctrl.runJavaScript(
              "(function(){"
              "var s=document.createElement('style');"
              "s.textContent="
              "  'html,body{margin:0;padding:0;background:#000;overflow:hidden}'"
              "  + '#wpadminbar,.site-header,.site-footer,header,footer,"
              "    .tutor-course-single-sidebar-wrapper,"
              "    .tutor-course-topic-single-header,"
              "    .tutor-course-spotlight-wrapper"
              "    {display:none!important}'"
              "  + '.tutor-course-topic-single-body>*:not(.tutor-video-player-wrapper)"
              "    {display:none!important}'"
              "  + '#tutor-single-entry-content,.tutor-course-topic-single-body"
              "    {padding:0!important;margin:0!important;background:#000}'"
              "  + '.tutor-video-player-wrapper,.tutor-video-player"
              "    {width:100vw!important;margin:0!important}'"
              "  + '.uvw-watermark{display:none!important}';"
              "document.head.appendChild(s);"
              "function safePost(m){"
              "  try{AppChannel.postMessage(m)}catch(e){}"
              "  try{VideoEvents.postMessage(m)}catch(e){}"
              "}"
              "var tries=0,iv=setInterval(function(){"
              "  tries++;"
              "  var w=document.querySelector('.tutor-video-player .plyr');"
              "  if(w){"
              "    var p=(window.Plyr&&Plyr.instances&&Plyr.instances[0])||w.plyr;"
              "    if(p){"
              "      p.on('play',function(){safePost('play')});"
              "      p.on('pause',function(){safePost('pause')});"
              "      p.on('ended',function(){safePost('ended')});"
              "      p.on('timeupdate',function(){try{safePost('time:'+Math.floor(p.currentTime))}catch(e){}});"
              "      clearInterval(iv);"
              "      safePost('ready');"
              "      return;"
              "    }"
              "  }"
              "  if(tries>40)clearInterval(iv);"
              "},500);"
              "})();"
            );
          }
          setState(() => _loading = false);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) {
            setState(() {
              _hasError = true;
              _errorMsg = 'خطأ في تحميل المشغّل (${e.errorCode})';
              _loading  = false;
            });
          }
        },
        onNavigationRequest: (req) {
          final uri  = Uri.tryParse(req.url);
          final host = uri?.host ?? '';
          // اسمح بالموقع وكل موارده
          final allowed = [
            'eduvision3.com',
            'youtube.com',
            'googlevideo.com',
            'ytimg.com',
            'ggpht.com',
            'googleusercontent.com',
            'player.vimeo.com',
            'vimeo.com',
            'vimeocdn.com',
            'fonts.googleapis.com',
            'fonts.gstatic.com',
            'gravatar.com',
          ];
          // امنع فقط الروابط التي تفتح صفحة خارجية كاملة (ليست resource)
          final isAllowed = allowed.any((h) => host.endsWith(h));
          if (!isAllowed) return NavigationDecision.prevent;
          // امنع التنقل لصفحات أخرى داخل الموقع (غير صفحة الدرس الحالية)
          if (host.endsWith('eduvision3.com') && req.isMainFrame) {
            final path = uri?.path ?? '';
            final isLesson = path.contains('/lessons/') || path.contains('lesson');
            if (!isLesson) return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      // AppChannel — القناة الرئيسية (safePost في PHP تستخدمها)
      ..addJavaScriptChannel(
        'AppChannel',
        onMessageReceived: _onVideoEvent,
      )
      // VideoEvents — backward compat
      ..addJavaScriptChannel(
        'VideoEvents',
        onMessageReceived: _onVideoEvent,
      )
      // loadRequest مع JWT
      ..loadRequest(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

    setState(() => _webCtrl = ctrl);
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _onVideoEvent(JavaScriptMessage msg) {
    final data = msg.message;

    // ── TVVL: رسالة الحجب من صفحة video_player.php ───────────────────────
    if (data.contains('"tvvl_blocked"') || data.contains('tvvl_blocked')) {
      _handleTvvlBlocked(data);
      return;
    }
    if (data.contains('"tvvl_open_whatsapp"')) {
      _handleTvvlWhatsapp(data);
      return;
    }

    if (data == 'ended' && !_completionFired) {
      _completionFired = true;
      _handleCompletion();
    } else if (data.startsWith('time:')) {
      final sec = int.tryParse(data.substring(5)) ?? 0;
      VideoProgressService.instance.savePosition(_current.id, sec);
    } else if (data.startsWith('pdf:')) {
      // فتح PDF في bottom sheet
      final pdfUrl = data.substring(4);
      _openPdf(pdfUrl);
    } else if (data.startsWith('open:')) {
      // فتح رابط خارجي (مرفق غير PDF)
      final openUrl = data.substring(5);
      _openPdf(openUrl);
    } else if (data.startsWith('error:')) {
      // خطأ من Plyr — اعرض رسالة واضحة للمستخدم
      final parts = data.split(':');
      final errorMsg = parts.length >= 3 ? parts.sublist(2).join(':') : 'خطأ في تشغيل الفيديو';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'إغلاق',
              textColor: Colors.white,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  // ── TVVL: معالجة رسالة الحجب ─────────────────────────────────────────────

  void _handleTvvlBlocked(String jsonStr) {
    if (!mounted) return;
    Map<String, dynamic> payload = {};
    try {
      // استخراج JSON من الرسالة
      final start = jsonStr.indexOf('{');
      final end   = jsonStr.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final clean = jsonStr.substring(start, end + 1);
        // تحليل يدوي خفيف — بدون dart:convert import إضافي
        payload = _parseSimpleJson(clean);
      }
    } catch (_) {}

    final planName  = payload['plan_name']  as String? ?? '';
    final viewsMax  = payload['max_views']  ?? 0;
    final nextPlan  = payload['next_plan']  as String? ?? '';
    final waUrl     = payload['wa_url']     as String? ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TvvlBlockedDialog(
        planName:  planName,
        viewsMax:  viewsMax is int ? viewsMax : int.tryParse('$viewsMax') ?? 0,
        nextPlan:  nextPlan,
        waUrl:     waUrl,
        onClose:   () => Navigator.of(context).pop(),
      ),
    );
  }

  void _handleTvvlWhatsapp(String jsonStr) {
    // المستخدم ضغط زر واتساب داخل WebView — نفتحه في التطبيق الخارجي
    try {
      final start  = jsonStr.indexOf('"wa_url"');
      if (start < 0) return;
      final colon  = jsonStr.indexOf(':', start);
      final q1     = jsonStr.indexOf('"', colon + 1);
      final q2     = jsonStr.indexOf('"', q1 + 1);
      if (q1 < 0 || q2 < 0) return;
      final waUrl  = jsonStr.substring(q1 + 1, q2);
      if (waUrl.isNotEmpty) {
        launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// تحليل JSON بسيط بدون حزمة إضافية
  Map<String, dynamic> _parseSimpleJson(String s) {
    final result = <String, dynamic>{};
    // نمط: "key": "value" أو "key": number أو "key": null
    final re = RegExp(r'"(\w+)"\s*:\s*(?:"([^"]*)"|([\d.]+)|(null|true|false))');
    for (final m in re.allMatches(s)) {
      final key = m.group(1)!;
      if (m.group(2) != null)      result[key] = m.group(2);
      else if (m.group(3) != null) result[key] = int.tryParse(m.group(3)!) ?? double.tryParse(m.group(3)!);
      else if (m.group(4) == 'null')  result[key] = null;
      else if (m.group(4) == 'true')  result[key] = true;
      else if (m.group(4) == 'false') result[key] = false;
    }
    return result;
  }

  Future<void> _handleCompletion() async {
    await ref
        .read(markLessonCompleteUseCaseProvider)
        .call(_current.id, widget.courseId);
    await VideoProgressService.instance.clearPosition(_current.id);
    if (!mounted) return;

    final idx     = widget.allLessons.indexWhere((l) => l.id == _current.id);
    final hasNext = idx >= 0 && idx < widget.allLessons.length - 1;

    if (hasNext) {
      final next = widget.allLessons[idx + 1];
      if (next.hasVideo) {
        setState(() => _current = next);
        await _loadLesson(next);
      } else {
        _showNextSnack(next.title);
      }
    } else {
      await ref.read(markCourseCompleteUseCaseProvider).call(widget.courseId);
      if (mounted) _showCourseComplete();
    }
  }

  // ── PDF Viewer ────────────────────────────────────────────────────────────

  Future<void> _openPdf(String url) async {
    final token = await SecureStorageService.instance.getToken() ?? '';
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(children: [
          Container(
            height: 48,
            color: const Color(0xFF1A1A1A),
            child: Row(children: [
              const SizedBox(width: 16),
              const Text('عرض الملف',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(url),
                    headers: {'Authorization': 'Bearer $token'}),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Snackbars / Dialogs ───────────────────────────────────────────────────

  void _showNextSnack(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('أحسنت! الدرس التالي: $title'),
      duration: const Duration(seconds: 4),
    ));
  }

  void _showCourseComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
        title: const Text('🎉 أتممت الدورة!', textAlign: TextAlign.center),
        content: const Text('لقد أكملت جميع دروس هذه الدورة بنجاح',
            textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('العودة للدورة'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(_current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${widget.allLessons.indexWhere((l) => l.id == _current.id) + 1}'
                  '/${widget.allLessons.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        body: Column(children: [
          // ── Video Area ────────────────────────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(children: [
              if (_webCtrl != null)
                WebViewWidget(
                  controller: _webCtrl!,
                  layoutDirection: TextDirection.rtl,
                ),
              if (_loading)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              if (_hasError)
                ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(_errorMsg,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => _loadLesson(_current),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('إعادة المحاولة',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ]),
                  ),
                ),
            ]),
          ),

          // ── Playlist ──────────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    Expanded(
                      child: Text(_current.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    if (_current.videoDuration.isNotEmpty)
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(_current.videoDuration,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ]),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.allLessons.length,
                    itemBuilder: (_, i) {
                      final l         = widget.allLessons[i];
                      final isCurrent = l.id == _current.id;
                      return ListTile(
                        dense: true,
                        tileColor: isCurrent
                            ? theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3)
                            : null,
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : l.isCompleted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            isCurrent
                                ? Icons.play_arrow_rounded
                                : l.isCompleted
                                    ? Icons.check_rounded
                                    : Icons.play_arrow_rounded,
                            color: isCurrent
                                ? Colors.white
                                : l.isCompleted
                                    ? Colors.green
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                            size: 16,
                          ),
                        ),
                        title: Text(l.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : null)),
                        subtitle: l.videoDuration.isNotEmpty
                            ? Text(l.videoDuration,
                                style: const TextStyle(fontSize: 11))
                            : null,
                        onTap: l.hasVideo && !isCurrent
                            ? () {
                                setState(() => _current = l);
                                _loadLesson(l);
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TVVL: Dialog الحجب — يظهر فوق شاشة الفيديو عند انتهاء المشاهدات
// ══════════════════════════════════════════════════════════════════════════════

class _TvvlBlockedDialog extends StatelessWidget {
  final String planName;
  final int    viewsMax;
  final String nextPlan;
  final String waUrl;
  final VoidCallback onClose;

  const _TvvlBlockedDialog({
    required this.planName,
    required this.viewsMax,
    required this.nextPlan,
    required this.waUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: .3),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⏳', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),

            // العنوان
            const Text(
              'انتهت المشاهدات المتاحة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // التفاصيل
            Text(
              'وصلت للحد الأقصى ($viewsMax مشاهدة)\nفي خطة «$planName»',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.6),
            ),

            // الترقية
            if (nextPlan.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2000),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0xFF4A3800)),
                ),
                child: Text(
                  '✨ الترقية إلى: $nextPlan',
                  style: const TextStyle(color: Color(0xFFF0A500), fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // زر واتساب
            if (waUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                  icon: const Text('💬', style: TextStyle(fontSize: 18)),
                  label: Text(
                    nextPlan.isNotEmpty
                        ? 'الترقية إلى $nextPlan عبر واتساب'
                        : 'تواصل معنا على واتساب',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(waUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // زر العودة
            TextButton(
              onPressed: onClose,
              child: Text(
                'العودة للكورس',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
