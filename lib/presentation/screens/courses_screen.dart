import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bundle.dart';
import '../providers/auth_provider.dart';
import '../providers/bundles_provider.dart';

// ── Palette shortcuts ─────────────────────────────────────────────────────────
const _bg     = AppTheme.mocha700;   // 472D30 — scaffold bg
const _plum   = AppTheme.mocha500;   // 723D46
const _mocha  = AppTheme.mocha700;   // 472D30
const _coral  = AppTheme.coral500;   // E26D5C
const _peach  = AppTheme.peach500;   // FFE1A8
const _sage   = AppTheme.sage500;    // C9CBA3
const _white  = Colors.white;

BoxShadow _sh(double b, {Color c = Colors.black, double o = 0.12}) =>
    BoxShadow(color: c.withValues(alpha: o), blurRadius: b, offset: Offset(0, b * 0.4));

// ── Sort state ────────────────────────────────────────────────────────────────
class _Sort {
  static const newest   = 'newest';
  static const enrolled = 'enrolled';
  static String label(String s) => switch (s) {
    enrolled => 'المسجّل أولاً',
    _        => 'الافتراضي',
  };
}

// ══════════════════════════════════════════════════════════════════════════════
//  Courses Screen
// ══════════════════════════════════════════════════════════════════════════════
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});
  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  final _searchCtrl = TextEditingController();
  String _q      = '';
  String _sort   = _Sort.newest;
  bool   _onlyEnrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWhenReady());
  }

  Future<void> _fetchWhenReady() async {
    for (var i = 0; i < 50; i++) {
      if (ref.read(authProvider) is! AuthInitial) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    ref.read(bundlesProvider.notifier).fetch();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Bundle> _apply(List<Bundle> all) {
    var r = all;
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      r = r.where((b) => b.title.toLowerCase().contains(q)).toList();
    }
    if (_onlyEnrolled) r = r.where((b) => b.isEnrolled).toList();
    if (_sort == _Sort.enrolled) {
      r = [...r]..sort((a, b) => (b.isEnrolled ? 1 : 0) - (a.isEnrolled ? 1 : 0));
    }
    return r;
  }

  bool get _hasFilter => _q.isNotEmpty || _onlyEnrolled || _sort != _Sort.newest;

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(bundlesProvider);
    final all      = state.bundles;
    final filtered = _apply(all);
    final enrolledCount = all.where((b) => b.isEnrolled).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: RefreshIndicator(
          color: _coral,
          backgroundColor: _white,
          onRefresh: () => ref.read(bundlesProvider.notifier).fetch(refresh: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [

              // ── Pinned AppBar + search ──────────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: true,
                snap: true,
                backgroundColor: _bg,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                expandedHeight: 0,
                title: Row(children: [
                  const Text('الحزم التعليمية',
                      style: TextStyle(
                          color: _white, fontWeight: FontWeight.w800, fontSize: 18)),
                  const Spacer(),
                  if (all.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _sage.withValues(alpha: 0.3)),
                      ),
                      child: Text('${all.length} حزمة',
                          style: TextStyle(
                              color: _white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ]),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(58),
                  child: Container(
                    color: _bg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(children: [
                      // Search field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _white.withValues(alpha: 0.18)),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: _white, fontSize: 13),
                            onChanged: (v) => setState(() => _q = v),
                            decoration: InputDecoration(
                              hintText: 'ابحث عن حزمة...',
                              hintStyle: TextStyle(
                                  color: _white.withValues(alpha: 0.45), fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: _white.withValues(alpha: 0.55), size: 20),
                              suffixIcon: _q.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.close_rounded,
                                          color: _white.withValues(alpha: 0.6), size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _q = '');
                                      })
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter button
                      Stack(children: [
                        GestureDetector(
                          onTap: () => _showFilterSheet(context, all, enrolledCount),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: _hasFilter
                                  ? _coral.withValues(alpha: 0.25)
                                  : _white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: _hasFilter
                                    ? _coral.withValues(alpha: 0.5)
                                    : _white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: _hasFilter ? _coral : _white, size: 20),
                          ),
                        ),
                        if (_hasFilter)
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: _coral, shape: BoxShape.circle),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ── Sort bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: _bg,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(children: [
                    for (final s in [
                      (_Sort.newest,   'الافتراضي',     Icons.grid_view_rounded),
                      (_Sort.enrolled, 'المسجّل أولاً', Icons.check_circle_outline_rounded),
                    ]) ...[
                      GestureDetector(
                        onTap: () => setState(() => _sort = s.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _sort == s.$1
                                ? _coral
                                : _white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _sort == s.$1
                                  ? _coral
                                  : _white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(s.$3,
                                size: 13,
                                color: _sort == s.$1
                                    ? _white
                                    : _white.withValues(alpha: 0.55)),
                            const SizedBox(width: 5),
                            Text(s.$2,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _sort == s.$1
                                        ? _white
                                        : _white.withValues(alpha: 0.55))),
                          ]),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (filtered.isNotEmpty)
                      Text('${filtered.length} حزمة',
                          style: TextStyle(
                              fontSize: 11,
                              color: _white.withValues(alpha: 0.45))),
                  ]),
                ),
              ),

              // ── Active filter chips ─────────────────────────────────────
              if (_hasFilter)
                SliverToBoxAdapter(
                  child: Container(
                    color: _bg,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Wrap(spacing: 8, runSpacing: 6, children: [
                      if (_q.isNotEmpty)
                        _FilterPill(
                          label: 'بحث: $_q',
                          onDelete: () {
                            _searchCtrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                      if (_onlyEnrolled)
                        _FilterPill(
                          label: 'المسجّلة فقط',
                          icon: Icons.check_circle_outline_rounded,
                          onDelete: () => setState(() => _onlyEnrolled = false),
                        ),
                      if (_sort != _Sort.newest)
                        _FilterPill(
                          label: _Sort.label(_sort),
                          icon: Icons.sort_rounded,
                          onDelete: () => setState(() => _sort = _Sort.newest),
                        ),
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() {
                            _q = ''; _sort = _Sort.newest; _onlyEnrolled = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('مسح الكل',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _white.withValues(alpha: 0.6))),
                        ),
                      ),
                    ]),
                  ),
                ),

              // ── White content area ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: const SizedBox(height: 20),
                ),
              ),

              // ── Loading ─────────────────────────────────────────────────
              if (state.isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const _CardShimmer(),
                      childCount: 6,
                    ),
                  ),
                )

              // ── Error ────────────────────────────────────────────────────
              else if (state.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    color: AppTheme.sage100,
                    child: _ErrorView(
                      message: state.error!,
                      onRetry: () => ref.read(bundlesProvider.notifier).fetch(),
                    ),
                  ),
                )

              // ── Empty ────────────────────────────────────────────────────
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    color: AppTheme.sage100,
                    child: _EmptyView(hasQuery: _q.isNotEmpty, query: _q),
                  ),
                )

              // ── Grid ─────────────────────────────────────────────────────
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _BundleCard(bundle: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              // ── Footer bg filler ─────────────────────────────────────────
              const SliverToBoxAdapter(
                child: ColoredBox(color: _bg,
                    child: SizedBox(height: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────
  void _showFilterSheet(
      BuildContext context, List<Bundle> all, int enrolledCount) {
    var tempSort         = _sort;
    var tempOnlyEnrolled = _onlyEnrolled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.75,
          minChildSize: 0.35,
          expand: false,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.sage100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: AppTheme.sage500, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Text('فلترة الحزم',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _mocha)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setModal(() {
                      tempSort = _Sort.newest;
                      tempOnlyEnrolled = false;
                    }),
                    child: const Text('إعادة ضبط',
                        style: TextStyle(color: _coral)),
                  ),
                ]),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Sort ─────────────────────────────────────────────
                    const Text('ترتيب حسب',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _mocha)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in [
                        (_Sort.newest,   'الافتراضي',     Icons.grid_view_rounded),
                        (_Sort.enrolled, 'المسجّل أولاً', Icons.check_circle_outline_rounded),
                      ])
                        GestureDetector(
                          onTap: () => setModal(() => tempSort = s.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: tempSort == s.$1
                                  ? _coral
                                  : AppTheme.sage200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(s.$3,
                                  size: 14,
                                  color: tempSort == s.$1
                                      ? _white
                                      : AppTheme.textMuted),
                              const SizedBox(width: 6),
                              Text(s.$2,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: tempSort == s.$1
                                          ? _white
                                          : AppTheme.textMuted)),
                            ]),
                          ),
                        ),
                    ]),

                    const SizedBox(height: 22),

                    // ── Toggle enrolled ──────────────────────────────────
                    if (enrolledCount > 0) ...[
                      const Text('تصفية',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _mocha)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () =>
                            setModal(() => tempOnlyEnrolled = !tempOnlyEnrolled),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: tempOnlyEnrolled
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.sage200,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tempOnlyEnrolled
                                  ? AppTheme.success.withValues(alpha: 0.4)
                                  : AppTheme.sage500.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              tempOnlyEnrolled
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: tempOnlyEnrolled
                                  ? AppTheme.success
                                  : AppTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text('المسجّلة فقط ($enrolledCount حزمة)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: tempOnlyEnrolled
                                        ? AppTheme.success
                                        : _mocha)),
                          ]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Apply
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          _sh(12, c: _coral, o: 0.3),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sort = tempSort;
                            _onlyEnrolled = tempOnlyEnrolled;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('تطبيق',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _white)),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Bundle Card — Grid card (2 columns)
// ══════════════════════════════════════════════════════════════════════════════
class _BundleCard extends StatefulWidget {
  final Bundle bundle;
  const _BundleCard({required this.bundle});

  @override
  State<_BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends State<_BundleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bundle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.push('/bundle/${b.id}');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: b.isEnrolled
                  ? AppTheme.success.withValues(alpha: 0.4)
                  : AppTheme.sage500.withValues(alpha: 0.5),
              width: b.isEnrolled ? 1.5 : 1,
            ),
            boxShadow: [
              _sh(10,
                  c: b.isEnrolled ? AppTheme.success : _mocha,
                  o: 0.08),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Thumbnail ───────────────────────────────────────────
              Expanded(
                flex: 5,
                child: Stack(fit: StackFit.expand, children: [
                  b.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: b.thumbnail,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _GradBg(index: b.id))
                      : _GradBg(index: b.id),

                  // scrim
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // status badge — أعلى اليسار
                  Positioned(
                    top: 8, left: 8,
                    child: b.isEnrolled
                        ? _Pill(
                            label: 'مسجّل',
                            bg: AppTheme.success,
                            icon: Icons.check_rounded)
                        : const SizedBox.shrink(),
                  ),

                  // course count — أسفل اليمين
                  Positioned(
                    bottom: 7, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.library_books_rounded,
                            size: 9, color: _white),
                        const SizedBox(width: 3),
                        Text('${b.courseCount}',
                            style: const TextStyle(
                                color: _white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ]),
              ),

              // ── Info ────────────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _mocha,
                              height: 1.3)),

                      const Spacer(),

                      // Progress bar (if enrolled)
                      if (b.isEnrolled) ...[
                        _MiniProgress(courses: b.courses),
                        const SizedBox(height: 6),
                      ],

                      // CTA chip
                      b.isEnrolled
                          ? _ChipBtn(
                              label: 'ابدأ',
                              icon: Icons.play_arrow_rounded,
                              bg: AppTheme.successLight,
                              fg: AppTheme.success,
                              gradient: null)
                          : _ChipBtn(
                              label: 'أدخل كود',
                              icon: Icons.vpn_key_rounded,
                              bg: null,
                              fg: _white,
                              gradient: AppTheme.buttonGradient),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini Progress ─────────────────────────────────────────────────────────────
class _MiniProgress extends StatelessWidget {
  final List<BundleCourse> courses;
  const _MiniProgress({required this.courses});

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) return const SizedBox.shrink();
    final cnt = courses.where((c) => c.isEnrolled).length;
    final pct = cnt / courses.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 4,
              backgroundColor: AppTheme.success.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppTheme.success)),
          ),
        ),
        const SizedBox(width: 5),
        Text('${(pct * 100).round()}%',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.success)),
      ]),
    ]);
  }
}

// ── Chip Button ───────────────────────────────────────────────────────────────
class _ChipBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? bg;
  final Color fg;
  final LinearGradient? gradient;
  const _ChipBtn({
    required this.label, required this.icon,
    required this.bg, required this.fg, required this.gradient,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      gradient: gradient,
      color: bg,
      borderRadius: BorderRadius.circular(10),
      boxShadow: gradient != null
          ? [_sh(8, c: _coral, o: 0.25)] : null,
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 13, color: fg),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    ]),
  );
}

// ── Pill Badge ────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final IconData icon;
  const _Pill({required this.label, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [_sh(6, c: bg, o: 0.35)],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: _white),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: _white, fontSize: 9.5, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ── Filter Pill ───────────────────────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onDelete;
  const _FilterPill({required this.label, this.icon, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
    decoration: BoxDecoration(
      color: _coral.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _coral.withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: _coral),
        const SizedBox(width: 4),
      ],
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: _coral)),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onDelete,
        child: const Icon(Icons.close_rounded, size: 13, color: _coral),
      ),
    ]),
  );
}

// ── Gradient Background ───────────────────────────────────────────────────────
class _GradBg extends StatelessWidget {
  final int index;
  const _GradBg({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.categoryGradients[index % AppTheme.categoryGradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(
        child: Icon(Icons.collections_bookmark_rounded,
            size: 32, color: Colors.white24)),
    );
  }
}

// ── Shimmer Card ──────────────────────────────────────────────────────────────
class _CardShimmer extends StatelessWidget {
  const _CardShimmer();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: AppTheme.sage300,
    highlightColor: AppTheme.sage100,
    child: Container(
      decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// ── Error View ────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _coral.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 40, color: _coral)),
        const SizedBox(height: 14),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _mocha.withValues(alpha: 0.6))),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [_sh(10, c: _coral, o: 0.3)]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, color: _white, size: 16),
              SizedBox(width: 8),
              Text('إعادة المحاولة',
                  style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ── Empty View ────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final bool hasQuery;
  final String query;
  const _EmptyView({required this.hasQuery, required this.query});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _sage.withValues(alpha: 0.25), shape: BoxShape.circle),
        child: const Icon(Icons.folder_off_outlined, size: 40, color: _plum)),
      const SizedBox(height: 12),
      Text(hasQuery ? 'لا نتائج لـ "$query"' : 'لا توجد حزم متاحة',
          style: TextStyle(
              color: _mocha.withValues(alpha: 0.55), fontSize: 14)),
    ]),
  );
}
