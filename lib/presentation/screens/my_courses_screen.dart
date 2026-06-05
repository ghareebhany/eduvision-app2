import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/dashboard_provider.dart';

// ── Shadow helper ─────────────────────────────────────────────────────────────
BoxShadow _shadow(double blur,
        {Color base = Colors.black, double opacity = 0.08}) =>
    BoxShadow(
        color: base.withValues(alpha: opacity),
        blurRadius: blur,
        offset: Offset(0, blur * 0.4));

// ══════════════════════════════════════════════════════════════════════════════
//  My Courses Screen
// ══════════════════════════════════════════════════════════════════════════════
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (label: 'الكل', status: 'all'),
    (label: 'قيد التعلم', status: 'active'),
    (label: 'المكتملة', status: 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.sageLight,
      body: Column(children: [
        // ── Custom header ──────────────────────────────────────────────
        _MyCoursesHeader(tabCtrl: _tabCtrl, tabs: _tabs),

        // ── Tab content ────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children:
                _tabs.map((t) => _CoursesList(status: t.status)).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Custom Header with gradient + TabBar ──────────────────────────────────────
class _MyCoursesHeader extends StatelessWidget {
  final TabController tabCtrl;
  final List<({String label, String status})> tabs;
  const _MyCoursesHeader({required this.tabCtrl, required this.tabs});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            gradient: AppPalette.headerGradient,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(24))),
        child: Stack(children: [
          // Deco circles
          Positioned(
              top: -20,
              right: -16,
              child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.sage.withValues(alpha: 0.10)))),
          Positioned(
              bottom: -12,
              left: 8,
              child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.coral.withValues(alpha: 0.12)))),

          SafeArea(
            bottom: false,
            child: Column(children: [
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18))),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('دوراتي',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ]),
              ),

              // TabBar
              TabBar(
                controller: tabCtrl,
                tabs: tabs.map((t) => Tab(text: t.label)).toList(),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppPalette.coral.withValues(alpha: 0.35),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                dividerColor: Colors.transparent,
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      );
}

// ── قائمة الكورسات حسب الـ status ────────────────────────────────────────────
class _CoursesList extends ConsumerStatefulWidget {
  final String status;
  const _CoursesList({required this.status});

  @override
  ConsumerState<_CoursesList> createState() => _CoursesListState();
}

class _CoursesListState extends ConsumerState<_CoursesList> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = MyCoursesFilter(status: widget.status, page: _page);
    final async = ref.watch(myCourseItemsProvider(filter));

    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppPalette.coral)),
      error: (e, _) => AppErrorWidget(
        message: e.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.invalidate(myCourseItemsProvider(filter)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.sage.withValues(alpha: 0.25)),
                  child: Icon(
                    widget.status == 'completed'
                        ? Icons.verified_rounded
                        : Icons.menu_book_outlined,
                    size: 48,
                    color: AppPalette.plum.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.status == 'completed'
                      ? 'لم تكمل أي دورة بعد'
                      : widget.status == 'active'
                          ? 'لا توجد دورات قيد التعلم'
                          : 'لم تسجّل في أي دورة بعد',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.mocha.withValues(alpha: 0.6)),
                ),
                if (widget.status == 'all') ...[
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => context.go('/courses'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                          gradient: AppPalette.btnGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            _shadow(10,
                                base: AppPalette.coral, opacity: 0.28)
                          ]),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.explore_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('تصفح الدورات',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppPalette.coral,
          onRefresh: () async =>
              ref.invalidate(myCourseItemsProvider(filter)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _MyCourseCard(item: items[i]),
          ),
        );
      },
    );
  }
}

// ── بطاقة الكورس ──────────────────────────────────────────────────────────────
class _MyCourseCard extends StatelessWidget {
  final MyCourseItem item;
  const _MyCourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final course = item.course;
    final isCompleted = item.isCourseCompleted;

    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isCompleted
                  ? AppPalette.successGreen.withValues(alpha: 0.4)
                  : AppPalette.sage.withValues(alpha: 0.5),
              width: 1.5),
          boxShadow: [
            _shadow(10,
                base: isCompleted
                    ? AppPalette.successGreen
                    : AppPalette.mocha,
                opacity: 0.08)
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(19)),
              child: course.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: course.thumbnail,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _ThumbFallback(
                          isCompleted: isCompleted))
                  : _ThumbFallback(isCompleted: isCompleted),
            ),

            // Vignette
            Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                          Colors.transparent,
                          AppPalette.mocha.withValues(alpha: 0.55)
                        ])))),

            // Status badge
            if (isCompleted)
              Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppPalette.successGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: AppPalette.successGreen
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ]),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('مكتملة',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold)),
                    ]),
                  )),

            // Lesson count
            Positioned(
                bottom: 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('${course.totalLessons} درس',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold)),
                  ]),
                )),
          ]),

          // Info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppPalette.mocha,
                      height: 1.35)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_outline,
                    size: 13,
                    color: AppPalette.plum.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(course.instructorName,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mocha.withValues(alpha: 0.55))),
              ]),
              const SizedBox(height: 12),

              // Progress bar (only when not completed)
              if (!isCompleted) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: item.completedPercent / 100,
                    minHeight: 7,
                    backgroundColor:
                        AppPalette.sage.withValues(alpha: 0.4),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppPalette.coral),
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${item.completedLessons}/${course.totalLessons} درس',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppPalette.mocha.withValues(alpha: 0.5))),
                  const Spacer(),
                  Text('${item.completedPercent}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppPalette.coral,
                          fontSize: 12)),
                ]),
                const SizedBox(height: 12),
              ],

              // Action button
              SizedBox(
                width: double.infinity,
                child: isCompleted
                    ? GestureDetector(
                        onTap: () => context.push('/course/${course.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppPalette.plum.withValues(alpha: 0.4),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(14),
                            color: AppPalette.mocha.withValues(alpha: 0.04),
                          ),
                          child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.replay_rounded,
                                    size: 16, color: AppPalette.plum),
                                SizedBox(width: 6),
                                Text('مراجعة الدورة',
                                    style: TextStyle(
                                        color: AppPalette.plum,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ]),
                        ),
                      )
                    : GestureDetector(
                        onTap: () =>
                            context.push('/lessons/${course.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: AppPalette.btnGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              _shadow(8,
                                  base: AppPalette.coral, opacity: 0.28)
                            ],
                          ),
                          child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 18, color: Colors.white),
                                SizedBox(width: 6),
                                Text('استكمل التعلم',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ]),
                        ),
                      ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  final bool isCompleted;
  const _ThumbFallback({required this.isCompleted});

  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isCompleted
                  ? [AppPalette.successGreen, const Color(0xFF2D6347)]
                  : [AppPalette.plum, AppPalette.mocha]),
        ),
        child: Icon(
            isCompleted
                ? Icons.verified_rounded
                : Icons.play_circle_fill_rounded,
            size: 52,
            color: Colors.white.withValues(alpha: 0.3)),
      );
}
