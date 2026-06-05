// ════════════════════════════════════════════════════════════════════════════
//  NativeLessonScreen — مشغل فيديو مستقل بدون WebView
//
//  يستبدل WebViewLessonScreen بالكامل ويدعم:
//   • YouTube  → youtube_player_iframe  (controls=0 + overlay مخصص)
//   • Vimeo    → WebView مصغّر للـ iframe فقط (بدون صفحة الموقع)
//   • HTML5    → video_player + chewie
//   • نص فقط  → عرض نصي بسيط
//
//  الألوان: AppPalette (coral #E26D5C / plum #723D46 / mocha #472D30)
//  التبعيات المطلوبة (موجودة بالفعل في pubspec.yaml):
//   - youtube_player_iframe: ^5.2.2
//   - video_player: ^2.8.7
//   - chewie: ^1.7.5
//   - webview_flutter: ^4.7.0
//   - flutter_riverpod: ^2.5.1
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/secure_screen.dart';
import '../../domain/entities/lesson.dart';
import '../providers/di_providers.dart';
import '../screens/video_progress_service.dart';

// ── مساعد استخراج Video ID من يوتيوب ────────────────────────────────────────
String? _extractYouTubeId(String url) {
  if (url.isEmpty) return null;
  final patterns = [
    RegExp(r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})'),
    RegExp(r'v=([a-zA-Z0-9_-]{11})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(url);
    if (m != null) return m.group(1);
  }
  return null;
}

// ── مساعد استخراج Vimeo ID ────────────────────────────────────────────────────
String? _extractVimeoId(String url) {
  if (url.isEmpty) return null;
  final m = RegExp(r'vimeo\.com/(?:video/)?(\d+)').firstMatch(url);
  return m?.group(1);
}

// ════════════════════════════════════════════════════════════════════════════
//  الشاشة الرئيسية
// ════════════════════════════════════════════════════════════════════════════
class NativeLessonScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int courseId;
  final List<Lesson> allLessons;

  const NativeLessonScreen({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.allLessons,
  });

  @override
  ConsumerState<NativeLessonScreen> createState() => _NativeLessonScreenState();
}

class _NativeLessonScreenState extends ConsumerState<NativeLessonScreen> {
  late Lesson _current;
  bool _completionFired = false;

  @override
  void initState() {
    super.initState();
    _current = widget.lesson;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _switchLesson(Lesson lesson) {
    if (lesson.id == _current.id) return;
    setState(() {
      _current = lesson;
      _completionFired = false;
    });
  }

  Future<void> _handleCompletion() async {
    if (_completionFired) return;
    _completionFired = true;

    await ref
        .read(markLessonCompleteUseCaseProvider)
        .call(_current.id, widget.courseId);
    await VideoProgressService.instance.clearPosition(_current.id);

    if (!mounted) return;
    await _moveToNextLesson();
  }

  Future<void> _moveToNextLesson() async {
    final idx = widget.allLessons.indexWhere((l) => l.id == _current.id);
    final next = (idx >= 0 && idx + 1 < widget.allLessons.length)
        ? widget.allLessons[idx + 1]
        : null;

    if (next != null) {
      _switchLesson(next);
    } else {
      await ref.read(markCourseCompleteUseCaseProvider).call(widget.courseId);
      if (mounted) _showCourseComplete();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lessons = widget.allLessons;
    final idx = lessons.indexWhere((l) => l.id == _current.id);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx + 1 < lessons.length;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────────────
            _buildAppBar(),

            // ── منطقة الفيديو ────────────────────────────────────────────
            _VideoArea(
              key: ValueKey(_current.id),
              lesson: _current,
              onCompleted: _handleCompletion,
            ),

            // ── محتوى الدرس (إن وجد) ────────────────────────────────────
            if (_current.content.isNotEmpty)
              Expanded(
                child: Container(
                  color: const Color(0xFF111111),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _current.content,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.7,
                        fontFamily: 'Cairo',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              )
            else
              const Expanded(child: SizedBox()),

            // ── شريط التنقل ──────────────────────────────────────────────
            _buildNavBar(lessons, idx, hasPrev, hasNext),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      color: AppPalette.mocha,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                _current.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _showLessonsList,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNavBar(
      List<Lesson> lessons, int idx, bool hasPrev, bool hasNext) {
    return Container(
      color: AppPalette.mocha,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        top: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // زر السابق
          TextButton.icon(
            onPressed: hasPrev ? () => _switchLesson(lessons[idx - 1]) : null,
            icon: Icon(Icons.skip_previous_rounded,
                color: hasPrev ? AppPalette.coral : Colors.grey),
            label: Text('السابق',
                style: TextStyle(
                    color: hasPrev ? AppPalette.coral : Colors.grey)),
          ),
          // عداد الدروس
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.plum.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${idx + 1} / ${lessons.length}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          // زر التالي
          TextButton.icon(
            onPressed: hasNext ? () => _switchLesson(lessons[idx + 1]) : null,
            label: Text('التالي',
                style: TextStyle(
                    color: hasNext ? AppPalette.coral : Colors.grey)),
            icon: Icon(Icons.skip_next_rounded,
                color: hasNext ? AppPalette.coral : Colors.grey),
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
        backgroundColor: AppPalette.mocha,
        title: const Text('تهانينا 🎉',
            style: TextStyle(color: Colors.white)),
        content: const Text('أنهيت جميع دروس الكورس بنجاح',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('رجوع', style: TextStyle(color: AppPalette.coral)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView.builder(
        itemCount: widget.allLessons.length,
        itemBuilder: (_, i) {
          final l = widget.allLessons[i];
          final isCurrent = l.id == _current.id;
          return ListTile(
            leading: Icon(
              l.isQuiz
                  ? Icons.quiz_rounded
                  : l.isVideo
                      ? Icons.play_circle_outline_rounded
                      : Icons.article_rounded,
              color: isCurrent ? AppPalette.coral : Colors.white54,
              size: 20,
            ),
            title: Text(
              l.title,
              style: TextStyle(
                color: isCurrent ? AppPalette.coral : Colors.white,
                fontWeight:
                    isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textDirection: TextDirection.rtl,
            ),
            subtitle: l.videoDuration.isNotEmpty
                ? Text(l.videoDuration,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12))
                : null,
            trailing: l.isCompleted
                ? const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 18)
                : null,
            onTap: () {
              Navigator.pop(context);
              _switchLesson(l);
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _VideoArea — يختار المشغل المناسب حسب videoSource
// ════════════════════════════════════════════════════════════════════════════
class _VideoArea extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onCompleted;

  const _VideoArea({
    super.key,
    required this.lesson,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (lesson.isYoutube) {
      final ytId = _extractYouTubeId(lesson.videoUrl);
      if (ytId != null) {
        return _YouTubePlayer(videoId: ytId, onCompleted: onCompleted);
      }
    }

    if (lesson.isVimeo) {
      final vimeoId = _extractVimeoId(lesson.videoUrl);
      if (vimeoId != null) {
        return _VimeoPlayer(vimeoId: vimeoId, onCompleted: onCompleted);
      }
    }

    if (lesson.videoSource == 'html5' && lesson.videoUrl.isNotEmpty) {
      return _Html5Player(url: lesson.videoUrl, onCompleted: onCompleted);
    }

    if (lesson.videoSource == 'external_url' && lesson.videoUrl.isNotEmpty) {
      return _Html5Player(url: lesson.videoUrl, onCompleted: onCompleted);
    }

    // نص فقط أو مصدر غير مدعوم
    return _PlaceholderArea(lesson: lesson);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _YouTubePlayer
//  يستخدم youtube_player_iframe مع controls=0 تماماً كـ Plyr
//  + Overlay شفاف يمنع ظهور عناصر YouTube الأصلية
// ════════════════════════════════════════════════════════════════════════════
class _YouTubePlayer extends StatefulWidget {
  final String videoId;
  final VoidCallback onCompleted;

  const _YouTubePlayer(
      {required this.videoId, required this.onCompleted});

  @override
  State<_YouTubePlayer> createState() => _YouTubePlayerState();
}

class _YouTubePlayerState extends State<_YouTubePlayer> {
  late YoutubePlayerController _yt;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _completedFired = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _hideTimer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _yt = YoutubePlayerController(
      params: const YoutubePlayerParams(
        // ══ نفس إعدادات Plyr التي تخفي كل عناصر YouTube ══
        showControls: false,       // controls=0
        showFullscreenButton: false,
        mute: false,
        showVideoAnnotations: false,  // iv_load_policy=3
        playsInline: true,
        strictRelatedVideos: true,    // rel=0
        loop: false,
        enableCaption: false,
        pointerEvents: PointerEvents.none, // يمنع نقرات YouTube
      ),
    );

    _yt.loadVideoById(videoId: widget.videoId);

    // استمع لحالة المشغل
    _yt.listen((value) {
      if (!mounted) return;
      final newPos = value.position;
      final newDur = value.metaData.duration;
      final isPlaying = value.playerState == PlayerState.playing;

      setState(() {
        _position = newPos;
        _duration = newDur;
        _isPlaying = isPlaying;
      });

      // اكتشاف الانتهاء
      if (value.playerState == PlayerState.ended && !_completedFired) {
        _completedFired = true;
        widget.onCompleted();
      }
    });

    // مؤقت لتحديث شريط التقدم
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isPlaying) setState(() {});
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _yt.close();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    if (_isPlaying) {
      _yt.pauseVideo();
    } else {
      _yt.playVideo();
      _resetHideTimer();
    }
  }

  void _seekTo(Duration pos) {
    _yt.seekTo(seconds: pos.inSeconds.toDouble(), allowSeekAhead: true);
    _resetHideTimer();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final playerH = screenW * 9 / 16;

    return Container(
      width: screenW,
      height: playerH,
      color: Colors.black,
      child: Stack(
        children: [
          // ── YouTube iframe (بدون controls) ──────────────────────────────
          Positioned.fill(
            child: YoutubePlayer(
              controller: _yt,
              aspectRatio: 16 / 9,
            ),
          ),

          // ── طبقة شفافة تمنع نقرات YouTube وتستقبل نقراتنا ──────────────
          // هذه هي نفس فكرة Plyr: يضع div فوق iframe
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          // ── أدوات التحكم المخصصة ─────────────────────────────────────────
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: _buildControls(playerH),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(double playerH) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Stack(
      children: [
        // خلفية متدرجة في الأسفل
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // خلفية متدرجة في الأعلى (للزر الكبير)
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),

        // زر تشغيل / إيقاف في المنتصف
        Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppPalette.coral.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),

        // أدوات التحكم السفلية
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // شريط التقدم
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppPalette.coral,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: AppPalette.coral,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) {
                      final newPos = Duration(
                          milliseconds:
                              (v * _duration.inMilliseconds).toInt());
                      _seekTo(newPos);
                    },
                  ),
                ),

                // الوقت والأزرار
                Row(
                  children: [
                    // زر تشغيل صغير
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // الوقت
                    Text(
                      '${_fmt(_position)} / ${_fmt(_duration)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                    const Spacer(),
                    // تقديم 10 ثواني
                    GestureDetector(
                      onTap: () => _seekTo(_position + const Duration(seconds: 10)),
                      child: const Icon(Icons.forward_10_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    // ملء الشاشة
                    GestureDetector(
                      onTap: _toggleFullscreen,
                      child: const Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggleFullscreen() {
    // إدارة الاتجاه عند الضغط على زر ملء الشاشة
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _VimeoPlayer
//  يعرض Vimeo عبر WebView مصغّر للـ iframe فقط (بدون صفحة الموقع كاملة)
//  مع params تخفي عناصر Vimeo: title=0&byline=0&portrait=0
// ════════════════════════════════════════════════════════════════════════════
class _VimeoPlayer extends StatefulWidget {
  final String vimeoId;
  final VoidCallback onCompleted;

  const _VimeoPlayer({required this.vimeoId, required this.onCompleted});

  @override
  State<_VimeoPlayer> createState() => _VimeoPlayerState();
}

class _VimeoPlayerState extends State<_VimeoPlayer> {
  late WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // HTML بسيط يحتوي على Vimeo iframe مع إخفاء كل عناصر Vimeo
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html, body { width:100%; height:100%; background:#000; overflow:hidden; }
  iframe { width:100%; height:100%; border:none; display:block; }
</style>
</head>
<body>
<iframe
  src="https://player.vimeo.com/video/${widget.vimeoId}?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=0"
  allow="autoplay; fullscreen; picture-in-picture"
  allowfullscreen>
</iframe>
<script src="https://player.vimeo.com/api/player.js"></script>
<script>
  var player = new Vimeo.Player(document.querySelector('iframe'));
  player.on('ended', function() {
    if (window.VimeoChannel) VimeoChannel.postMessage('ended');
  });
</script>
</body>
</html>
''';

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('VimeoChannel',
          onMessageReceived: (msg) {
        if (msg.message == 'ended') widget.onCompleted();
      })
      ..loadHtmlString(html);

    if (_ctrl.platform is AndroidWebViewController) {
      (_ctrl.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _ctrl.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) {
        if (mounted) setState(() => _loading = false);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final playerH = screenW * 9 / 16;

    return SizedBox(
      width: screenW,
      height: playerH,
      child: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppPalette.coral),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _Html5Player
//  يستخدم video_player + chewie للفيديو المباشر (HTML5 / external_url)
// ════════════════════════════════════════════════════════════════════════════
class _Html5Player extends StatefulWidget {
  final String url;
  final VoidCallback onCompleted;

  const _Html5Player({required this.url, required this.onCompleted});

  @override
  State<_Html5Player> createState() => _Html5PlayerState();
}

class _Html5PlayerState extends State<_Html5Player> {
  VideoPlayerController? _vpc;
  ChewieController? _chewieCtrl;
  bool _loading = true;
  bool _error = false;
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _vpc!.initialize();

      _vpc!.addListener(() {
        if (!mounted) return;
        final ctrl = _vpc!;
        // اكتشاف انتهاء الفيديو
        if (ctrl.value.position >= ctrl.value.duration &&
            ctrl.value.duration > Duration.zero &&
            !_completedFired) {
          _completedFired = true;
          widget.onCompleted();
        }
      });

      _chewieCtrl = ChewieController(
        videoPlayerController: _vpc!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppPalette.coral,
          handleColor: AppPalette.coral,
          bufferedColor: AppPalette.plum.withOpacity(0.4),
          backgroundColor: Colors.white24,
        ),
      );

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _vpc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final playerH = screenW * 9 / 16;

    return Container(
      width: screenW,
      height: playerH,
      color: Colors.black,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppPalette.coral),
              ),
            )
          : _error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      const Text('تعذّر تشغيل الفيديو',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = false;
                          });
                          _initPlayer();
                        },
                        child: Text('إعادة المحاولة',
                            style: TextStyle(color: AppPalette.coral)),
                      ),
                    ],
                  ),
                )
              : Chewie(controller: _chewieCtrl!),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  _PlaceholderArea — درس نصي أو نوع غير مدعوم
// ════════════════════════════════════════════════════════════════════════════
class _PlaceholderArea extends StatelessWidget {
  final Lesson lesson;
  const _PlaceholderArea({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: AppPalette.mocha,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            lesson.isQuiz ? Icons.quiz_rounded : Icons.article_rounded,
            color: AppPalette.peach,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            lesson.isQuiz ? 'اختبار' : 'درس نصي',
            style: TextStyle(
                color: AppPalette.peach,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
