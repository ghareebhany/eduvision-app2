import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  final VoidCallback onVideoEnded;
  final Function(int) onTimeUpdate;

  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    required this.onVideoEnded,
    required this.onTimeUpdate,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;

  bool  _hasEnded     = false;
  bool  _showControls = true;
  int   _currentSec   = 0;
  int   _totalSec     = 0;
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls:         false,   // controls=0 → لا UI يوتيوب
        showFullscreenButton: false,
        mute:                 false,
        showVideoAnnotations: false,
        playsInline:          true,
        strictRelatedVideos:  true,
        loop:                 false,
        enableCaption:        false,
        pointerEvents:        PointerEvents.none,
      ),
    );

    _controller.loadVideoById(videoId: widget.videoId);

    // تحديث الوقت كل ثانية عبر Timer
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      try {
        final sec = (await _controller.currentTime).toInt();
        if (sec != _currentSec) {
          setState(() => _currentSec = sec);
          widget.onTimeUpdate(sec);
        }
        if (_totalSec == 0) {
          final dur = (await _controller.duration).toInt();
          if (dur > 0) setState(() => _totalSec = dur);
        }
        if (_totalSec > 0 && sec >= _totalSec - 1 && !_hasEnded) {
          _hasEnded = true;
          widget.onVideoEnded();
        }
      } catch (_) {}
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _scheduleHide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _seek(int delta) async {
    final target = (_currentSec + delta).clamp(0, _totalSec);
    await _controller.seekTo(seconds: target.toDouble(), allowSeekAhead: true);
    setState(() => _showControls = true);
    _scheduleHide();
  }

  String _fmt(int s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s  % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _controller.close();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSec > 0
        ? (_currentSec / _totalSec).clamp(0.0, 1.0)
        : 0.0;

    // ✅ YoutubeValueBuilder — الطريقة الصحيحة للوصول لـ playerState في v6
    return YoutubeValueBuilder(
      controller: _controller,
      builder: (context, value) {
        final isPlaying = value.playerState == PlayerState.playing;
        // isReady: نعتبر المشغّل جاهزاً عندما يكون في حالة غير unknown
        final isReady   = value.playerState != PlayerState.unknown && value.playerState != PlayerState.unStarted;

        // اختفاء controls بعد 3 ثوانٍ من بدء التشغيل
        if (isPlaying && _showControls) _scheduleHide();

        // كشف نهاية الفيديو
        if (value.playerState == PlayerState.ended && !_hasEnded) {
          _hasEnded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onVideoEnded();
          });
        }

        return AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _showControls = !_showControls);
              if (_showControls) _scheduleHide();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [

                // ── YouTube IFrame بدون أي UI ──────────────────────────
                YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),

                // ── Loading ────────────────────────────────────────────
                if (!isReady)
                  const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFe52027), strokeWidth: 2.5,
                      ),
                    ),
                  ),

                // ── Custom Controls (مثل Plyr) ─────────────────────────
                if (isReady)
                  AnimatedOpacity(
                    opacity:  _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _buildControls(
                      context, progress, isPlaying,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(
      BuildContext context, double progress, bool isPlaying) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Color(0xBB000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          const SizedBox(height: 32),

          // ── أزرار وسطى ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Btn(Icons.replay_10_rounded, onTap: () => _seek(-10)),
              const SizedBox(width: 28),
              _Btn(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                size:  60,
                onTap: () async {
                  isPlaying
                      ? await _controller.pauseVideo()
                      : await _controller.playVideo();
                  setState(() => _showControls = true);
                  _scheduleHide();
                },
              ),
              const SizedBox(width: 28),
              _Btn(Icons.forward_10_rounded, onTap: () => _seek(10)),
            ],
          ),

          // ── شريط التقدم ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   const Color(0xFFe52027),
                    inactiveTrackColor: Colors.white30,
                    thumbColor:         const Color(0xFFe52027),
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value:     progress,
                    onChanged: (v) async {
                      final t = (v * _totalSec).toInt();
                      await _controller.seekTo(
                          seconds: t.toDouble(), allowSeekAhead: true);
                      setState(() => _showControls = true);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_currentSec),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      Text(_fmt(_totalSec),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData     icon;
  final double       size;
  final VoidCallback onTap;
  const _Btn(this.icon, {required this.onTap, this.size = 38});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: Colors.white, size: size,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
  );
}
