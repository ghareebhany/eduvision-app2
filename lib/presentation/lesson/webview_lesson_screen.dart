import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/secure_storage.dart';
import '../../core/widgets/secure_screen.dart';
import '../../domain/entities/lesson.dart';
import '../providers/di_providers.dart';
import '../screens/video_progress_service.dart';

class WebViewLessonScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int courseId;
  final List<Lesson> allLessons;

  const WebViewLessonScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.allLessons,
  });

  @override
  ConsumerState<WebViewLessonScreen> createState() =>
      _WebViewLessonScreenState();
}

class _WebViewLessonScreenState extends ConsumerState<WebViewLessonScreen> {
  late Lesson _current;
  WebViewController? _ctrl;

  bool _loading          = true;
  bool _hasError         = false;
  bool _completionFired  = false;
  int? _currentLessonId;        // لتتبع الدرس الحالي عند التبديل

  @override
  void initState() {
    super.initState();
    _current          = widget.lesson;
    _currentLessonId  = widget.lesson.id;
    _loadLesson(_current);
  }

  @override
  void dispose() {
    // تسجيل المشاهدة يتم بالكامل من JS (beforeunload / visibilitychange / pagehide)
    // عبر fetch keepalive → /tvvl/v1/register-view، بدون تدخل من Dart لتجنب التسجيل المزدوج.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // تحميل الدرس
  // التوكن يُمرَّر كـ ?app=1&token=JWT في الـ URL
  // app_player.php يقرأه ويُسجّل المستخدم بـ wp_set_current_user()
  // Tutor LMS يُشغّل Plyr بنفسه ويُخفي عناصر يوتيوب تلقائياً
  // تسجيل المشاهدة يتم حصراً من tvvl-frontend.js عبر fetch keepalive
  // عند beforeunload / pagehide / visibilitychange لمنع التسجيل المزدوج.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadLesson(Lesson lesson) async {
    _currentLessonId = lesson.id;

    setState(() {
      _loading         = true;
      _hasError        = false;
      _completionFired = false;
      _ctrl            = null;
    });

    final token = await SecureStorageService.instance.getToken();
    if (token == null || token.isEmpty) {
      setState(() { _hasError = true; _loading = false; });
      return;
    }

    // ── بناء URL صفحة الدرس الحقيقية على الموقع ──────────────────────────
    // ?app=1 → يُفعّل app_player.php الذي يُحمّل صفحة Tutor LMS الأصلية
    // Tutor LMS يُشغّل Plyr بنفسه → يُخفي كل عناصر يوتيوب تلقائياً
    // بدلاً من video_player.php الذي يبني iframe يدوياً → عناصر يوتيوب تظهر
    final lessonUrl = _buildLessonUrl(lesson, token);

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          // UA كامل: Android + Mobile keyword ضروري لـ YouTube يتحقق منه
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..enableZoom(false);

    // ── Android WebView settings ───────────────────────────────────────────
    if (ctrl.platform is AndroidWebViewController) {
      (ctrl.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    ctrl
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
            _ctrl?.runJavaScript(
              '(function(){'
              // اعتراض نقرات واتساب
              '  document.addEventListener("click", function(e){'
              '    var el = e.target.closest ? e.target.closest("a[href]") : null;'
              '    if (!el) return;'
              '    var href = el.getAttribute("href") || "";'
              '    var isWa = href.indexOf("whatsapp://") === 0'
              '             || href.indexOf("https://wa.me") === 0'
              '             || href.indexOf("http://wa.me") === 0;'
              '    if (isWa) {'
              '      e.preventDefault(); e.stopPropagation();'
              '      if (window.WaChannel) { window.WaChannel.postMessage(href); }'
              '    }'
              '  }, true);'
              '})();'
            );
          },
          onWebResourceError: (e) {
            if ((e.isForMainFrame ?? false) && mounted) {
              setState(() { _hasError = true; _loading = false; });
            }
          },
          onNavigationRequest: (req) {
            final uri    = Uri.tryParse(req.url);
            final scheme = uri?.scheme ?? '';
            final host   = uri?.host ?? '';

            // ── روابط واتساب ───────────────────────────────────────────────
            final isWhatsApp = scheme == 'whatsapp' ||
                host == 'wa.me' ||
                host.endsWith('.wa.me');

            if (isWhatsApp && uri != null) {
              Uri launchUri = uri;
              if (scheme == 'whatsapp') {
                final phone = uri.queryParameters['phone'] ?? '';
                final text  = uri.queryParameters['text'] ?? '';
                if (phone.isNotEmpty) {
                  final encoded = Uri.encodeComponent(text);
                  launchUri = Uri.parse(
                    text.isNotEmpty
                        ? 'https://wa.me/$phone?text=$encoded'
                        : 'https://wa.me/$phone',
                  );
                }
              }
              launchUrl(launchUri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // ── روابط tel / mailto ─────────────────────────────────────────
            if ((scheme == 'tel' || scheme == 'mailto') && uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // ── السماح بكل طلبات الموقع وموفّري الفيديو والأصول ──────────
            // ⚠️ دومين موقعك مستخرج من ApiConstants.siteUrl تلقائياً
            // لا تكتب الدومين يدوياً هنا — استخدم _siteHost دائماً
            final isAllowed = _isAllowedHost(host);
            return isAllowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel('AppChannel',  onMessageReceived: _onVideoEvent)
      ..addJavaScriptChannel('VideoEvents', onMessageReceived: _onVideoEvent)
      ..addJavaScriptChannel('WaChannel',   onMessageReceived: _onWaLink)
      ..loadRequest(Uri.parse(lessonUrl));

    if (mounted) setState(() => _ctrl = ctrl);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // دومين الموقع مستخرج من ApiConstants.siteUrl
  // يعمل تلقائياً مع أي دومين بدون تعديل يدوي
  // ─────────────────────────────────────────────────────────────────────────
  static final String _siteHost =
      Uri.tryParse(ApiConstants.siteUrl)?.host ?? '';

  // قائمة الدومينات المسموح بها — موفّرو الفيديو والأصول الثابتة
  static const List<String> _videoProviders = [
    'youtube.com',
    'youtube-nocookie.com',
    'youtu.be',
    'ytimg.com',
    'googlevideo.com',
    'vimeo.com',
    'player.vimeo.com',
    'vimeocdn.com',
    'fonts.googleapis.com',
    'fonts.gstatic.com',
    'googleapis.com',
  ];

  bool _isAllowedHost(String host) {
    if (host.isEmpty) return false;
    // دومين الموقع نفسه (eduvision3.com أو أي دومين آخر)
    if (host == _siteHost || host.endsWith('.$_siteHost')) return true;
    // موفّرو الفيديو والأصول
    return _videoProviders.any((h) => host == h || host.endsWith('.$h'));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // بناء رابط الدرس بـ ?app=1&token=JWT
  // ─────────────────────────────────────────────────────────────────────────
  String _buildLessonUrl(Lesson lesson, String token) {
    // ✅ الأولوية: lessonUrl من API (صفحة الدرس الحقيقية على الموقع)
    // ?app=1 → يُفعّل app_player.php → Tutor LMS يُشغّل Plyr
    //        → يُخفي عناصر يوتيوب تلقائياً (مثل kwafledu تماماً)
    //
    // ❌ لا نستخدم: /wp-json/app/v1/lesson-view/{id}  (video_player.php)
    //    لأنه يبني iframe يدوياً → Tutor LMS لا يتدخل → عناصر يوتيوب تظهر
    if (lesson.lessonUrl.isNotEmpty) {
      return ApiConstants.appModeUrl(lesson.lessonUrl, token);
    }

    // Fallback: rewrite rule /app-player/{lesson_id}/?app=1&token=
    return ApiConstants.appPlayerUrl(lesson.id, token);
  }

  void _onWaLink(JavaScriptMessage msg) {
    final href = msg.message;
    Uri? uri;

    if (href.startsWith('whatsapp://')) {
      final raw = Uri.tryParse(href);
      final phone = raw?.queryParameters['phone'] ?? '';
      final text  = raw?.queryParameters['text'] ?? '';
      if (phone.isNotEmpty) {
        final encoded = Uri.encodeComponent(text);
        uri = Uri.parse(
          text.isNotEmpty
              ? 'https://wa.me/$phone?text=$encoded'
              : 'https://wa.me/$phone',
        );
      }
    } else {
      uri = Uri.tryParse(href);
    }

    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _onVideoEvent(JavaScriptMessage msg) {
    final data = msg.message;

    switch (data) {
      case 'ended':
        if (!_completionFired) {
          _completionFired = true;
          _handleCompletion();
        }
      case 'ready':
        if (mounted) setState(() => _loading = false);
      case 'play':
      case 'pause':
        break;
      default:
        if (data.startsWith('time:')) {
          final sec = int.tryParse(data.substring(5)) ?? 0;
          VideoProgressService.instance.savePosition(_current.id, sec);
        } else if (data.startsWith('pdf:')) {
          _openAttachment(data.substring(4));
        } else if (data.startsWith('open:')) {
          _openAttachment(data.substring(5));
        }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleCompletion() async {
    await ref
        .read(markLessonCompleteUseCaseProvider)
        .call(_current.id, widget.courseId);
    await VideoProgressService.instance.clearPosition(_current.id);
    if (!mounted) return;
    await _checkAndMoveToNextLesson();
  }

  Future<void> _checkAndMoveToNextLesson() async {
    if (!mounted) return;
    final idx  = widget.allLessons.indexWhere((l) => l.id == _current.id);
    final next = (idx >= 0 && idx + 1 < widget.allLessons.length)
        ? widget.allLessons[idx + 1]
        : null;

    if (next != null) {
      setState(() => _current = next);
      _loadLesson(next);
    } else {
      await ref.read(markCourseCompleteUseCaseProvider).call(widget.courseId);
      if (mounted) _showCourseComplete();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openAttachment(String url) async {
    final token = await SecureStorageService.instance.getToken() ?? '';
    if (!mounted) return;

    final attachUrl = url.contains('?')
        ? '$url&token=${Uri.encodeComponent(token)}'
        : '$url?token=${Uri.encodeComponent(token)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(attachUrl)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a1a),
          foregroundColor: Colors.white,
          title: Text(
            _current.title,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.list_rounded),
              onPressed: _showLessonsList,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_ctrl != null)
                    WebViewWidget(controller: _ctrl!),

                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFe52027)),
                      ),
                    ),

                  if (_hasError && !_loading)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          const Text('فشل تحميل الدرس',
                              style: TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => _loadLesson(_current),
                            icon: const Icon(Icons.refresh, color: Color(0xFFe52027)),
                            label: const Text('إعادة المحاولة',
                                style: TextStyle(color: Color(0xFFe52027))),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _buildNavBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNavBar() {
    final lessons = widget.allLessons;
    final idx     = lessons.indexWhere((l) => l.id == _current.id);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx + 1 < lessons.length;

    return Container(
      color: const Color(0xFF1a1a1a),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton(
            onPressed: hasPrev ? () => _loadLesson(lessons[idx - 1]) : null,
            style: TextButton.styleFrom(
              foregroundColor: hasPrev ? const Color(0xFFe52027) : Colors.grey,
            ),
            child: const Text('السابق'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${idx + 1} / ${lessons.length}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: hasNext ? () => _loadLesson(lessons[idx + 1]) : null,
            style: TextButton.styleFrom(
              foregroundColor: hasNext ? const Color(0xFFe52027) : Colors.grey,
            ),
            child: const Text('التالي'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _showCourseComplete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تهانينا 🎉'),
        content: const Text('أنهيت جميع دروس الكورس بنجاح'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _showLessonsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a1a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ListView.builder(
        itemCount: widget.allLessons.length,
        itemBuilder: (_, i) {
          final l         = widget.allLessons[i];
          final isCurrent = l.id == _current.id;
          return ListTile(
            title: Text(
              l.title,
              style: TextStyle(
                color:      isCurrent ? const Color(0xFFe52027) : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isCurrent
                ? const Icon(Icons.play_circle, color: Color(0xFFe52027), size: 20)
                : null,
            onTap: () {
              Navigator.pop(context);
              setState(() => _current = l);
              _loadLesson(l);
            },
          );
        },
      ),
    );
  }
}
