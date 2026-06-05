import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/failures.dart';
import '../../core/widgets/error_widget.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/review.dart';
import '../providers/courses_provider.dart';
import '../providers/di_providers.dart';
import '../providers/profile_provider.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _enrolling = false;

  // FIX: local state بسيط بدون أي provider magic
  // يُحدَّث فوراً بعد التسجيل ويبقى حتى يُغلق المستخدم الشاشة أو يُؤكد الـ server
  bool _enrolledLocally = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // الـ enrollment الفعلي = server value OR local override
  bool _effectiveEnrolled(Course course) => course.isEnrolled || _enrolledLocally;

  Future<void> _enroll(Course course) async {
    setState(() => _enrolling = true);

    final result = await ref.read(enrollCourseUseCaseProvider).call(course.id);
    if (!mounted) return;

    setState(() => _enrolling = false);

    result.fold(
      (f) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(f.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      },
      (_) {
        // FIX: حدّث الـ UI فوراً عبر local state — لا race conditions
        setState(() => _enrolledLocally = true);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'تم التسجيل بنجاح! ',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ));

        // FIX: أعد تحميل بعد 800ms — يُعطي الـ DB وقتاً للاستقرار
        // لا نستدعي invalidate فوراً لأن الـ backend قد يُعيد is_enrolled: false
        // بسبب الـ cache أو latency
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          // امسح الـ cache المحلي أولاً
          ref.read(courseRepositoryProvider); // warm provider
          // أعد تحميل الـ topics (الآن الـ server يُعيد البيانات بشكل صحيح)
          ref.invalidate(topicsProvider(widget.courseId));
          // أعد تحميل الكورس من الـ server للمزامنة (skipLoadingOnRefresh يحميه من الوميض)
          ref.invalidate(courseDetailProvider(widget.courseId));
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return courseAsync.when(
      // FIX: لا تُظهر loading أثناء refresh — يحمي من وميض الـ UI
      skipLoadingOnRefresh: true,
      skipLoadingOnReload:  true,
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
        ),
      ),
      data: (course) {
        // FIX: لما يُؤكد الـ server التسجيل — نُزيل الـ local flag
        // لأن course.isEnrolled أصبح true من الـ server مباشرة
        if (course.isEnrolled && _enrolledLocally) {
          // ScheduleMicrotask لتجنب setState أثناء build
          Future.microtask(() {
            if (mounted) setState(() => _enrolledLocally = false);
          });
        }
        return _buildScaffold(course);
      },
    );
  }

  Widget _buildScaffold(Course course) {
    final theme    = Theme.of(context);
    final enrolled = _effectiveEnrolled(course); // FIX: effective value

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: course.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: course.thumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: theme.colorScheme.primaryContainer),
                    )
                  : Container(color: theme.colorScheme.primaryContainer),
            ),
            title: Text(course.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16)),
          ),
          SliverToBoxAdapter(child: _courseHeader(course, theme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'عن الدورة'),
                  Tab(text: 'المحتوى'),
                  Tab(text: 'التقييمات'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _AboutTab(course: course),
            // FIX: مرّر enrolled الفعلي
            _ContentTab(courseId: course.id, isEnrolled: enrolled),
            _ReviewsTab(courseId: course.id),
          ],
        ),
      ),
      // FIX: مرّر enrolled الفعلي للـ bottom bar
      bottomNavigationBar: _buildBottomBar(course, theme, enrolled),
    );
  }

  Widget _courseHeader(Course course, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(course.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 16, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text('${course.rating.toStringAsFixed(1)} (${course.ratingCount})'),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('${course.totalEnrolled} طالب',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.menu_book_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('${course.totalLessons} درس',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ]),
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/instructor/${course.instructorId}'),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: course.instructorAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(course.instructorAvatar)
                    : null,
                child: course.instructorAvatar.isEmpty
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(course.instructorName,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  // FIX: يستقبل enrolled كـ parameter
  Widget _buildBottomBar(Course course, ThemeData theme, bool enrolled) {
    if (enrolled) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => context.push('/lessons/${course.id}'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ابدأ التعلم', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (!course.isFree) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السعر',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                Text(course.price,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: FilledButton(
              onPressed: _enrolling ? null : () => _enroll(course),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _enrolling
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      course.isFree ? 'التسجيل مجاناً' : 'التسجيل الآن',
                      style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tab: About ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final Course course;
  const _AboutTab({required this.course});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: course.description.isNotEmpty
            ? course.description
            : '<p>لا يوجد وصف متاح</p>',
      ),
    );
  }
}

// ── Tab: Content ──────────────────────────────────────────────────────────────

class _ContentTab extends ConsumerWidget {
  final int courseId;
  final bool isEnrolled;

  const _ContentTab({required this.courseId, required this.isEnrolled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(courseId));
    final theme = Theme.of(context);

    return topicsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        // FIX: إذا المستخدم سجّل محلياً ولكن الـ server لم يؤكد بعد
        // أظهر loading بدل رسالة الخطأ
        if (e is EnrollmentFailure && isEnrolled) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جارٍ تحميل المحتوى...'),
              ],
            ),
          );
        }
        if (e is EnrollmentFailure) {
          return _EnrollmentPlaceholder(onGoToEnroll: () {
            DefaultTabController.maybeOf(context)?.animateTo(0);
          });
        }
        return AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', ''),
          onRetry: () => ref.invalidate(topicsProvider(courseId)),
        );
      },
      data: (topics) {
        if (topics.isEmpty) {
          return Center(
              child: Text('لا يوجد محتوى بعد',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: topics.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final topic = topics[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                title: Text(topic.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${topic.lessons.length} درس',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                children: topic.lessons
                    .map((lesson) => _LessonTile(
                          lesson:     lesson,
                          courseId:   courseId,
                          isEnrolled: isEnrolled,
                          allLessons: topic.lessons,
                        ))
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Enrollment placeholder ────────────────────────────────────────────────────

class _EnrollmentPlaceholder extends StatelessWidget {
  final VoidCallback onGoToEnroll;
  const _EnrollmentPlaceholder({required this.onGoToEnroll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('سجّل في الدورة لعرض المحتوى',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onGoToEnroll,
              child: const Text('اذهب للتسجيل'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lesson Tile ───────────────────────────────────────────────────────────────

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final int courseId;
  final bool isEnrolled;
  final List<Lesson> allLessons;

  const _LessonTile({
    required this.lesson,
    required this.courseId,
    required this.isEnrolled,
    required this.allLessons,
  });

  void _onTap(BuildContext context) {
    if (!isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('سجّل في الدورة للوصول إلى هذا المحتوى'),
        action: SnackBarAction(
          label: 'التسجيل',
          onPressed: () =>
              DefaultTabController.maybeOf(context)?.animateTo(0),
        ),
      ));
      return;
    }

    if (lesson.isVideo) {
      // فيديو — مشغّل Tutor LMS الحقيقي
      context.push('/video/${lesson.id}', extra: {
        'lesson'    : lesson,
        'courseId'  : courseId,
        'allLessons': allLessons,
      });
    } else if (lesson.isQuiz) {
      // اختبار
      context.push('/quiz/${lesson.id}');
    } else if (lesson.isAssignment) {
      // واجب — يُعرض في WebView
      context.push('/lesson-web/${lesson.id}', extra: {'title': lesson.title});
    } else {
      // درس نصي أو PDF — يُعرض في lesson-view WebView
      context.push('/lesson-web/${lesson.id}', extra: {'title': lesson.title});
    }
  }

  IconData get _icon {
    if (lesson.isCompleted)   return Icons.check_rounded;
    if (!isEnrolled)          return Icons.lock_outline_rounded;
    if (lesson.isQuiz)        return Icons.quiz_rounded;
    if (lesson.isAssignment)  return Icons.assignment_rounded;
    if (lesson.isVideo)       return Icons.play_arrow_rounded;
    return Icons.article_outlined;
  }

  Color _iconColor(ThemeData t) {
    if (lesson.isCompleted)  return Colors.green;
    if (!isEnrolled)         return t.colorScheme.onSurface.withValues(alpha: 0.35);
    if (lesson.isQuiz)       return t.colorScheme.secondary;
    if (lesson.isAssignment) return t.colorScheme.tertiary;
    return t.colorScheme.primary;
  }

  Color _bgColor(ThemeData t) {
    if (lesson.isCompleted)  return Colors.green.withValues(alpha: 0.12);
    if (!isEnrolled)         return t.colorScheme.surfaceContainerHighest;
    if (lesson.isQuiz)       return t.colorScheme.secondaryContainer;
    if (lesson.isAssignment) return t.colorScheme.tertiaryContainer;
    return t.colorScheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final locked = !isEnrolled;

    return ListTile(
      onTap: () => _onTap(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _bgColor(theme)),
        child: Icon(_icon, size: 18, color: _iconColor(theme)),
      ),
      title: Text(lesson.title,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: locked
                ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                : null,
            decoration: lesson.isCompleted ? TextDecoration.lineThrough : null,
          )),
      subtitle: _buildSubtitle(theme),
      trailing: locked
          ? null
          : Icon(Icons.chevron_left_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final isSpecial = lesson.isQuiz || lesson.isAssignment;
    final duration  = lesson.videoDuration;
    if (!isSpecial && duration.isEmpty) return null;

    return Wrap(spacing: 6, children: [
      if (isSpecial)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: lesson.isQuiz
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            lesson.isQuiz ? 'اختبار' : 'واجب',
            style: TextStyle(
                fontSize: 11,
                color: lesson.isQuiz
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.tertiary),
          ),
        ),
      if (duration.isNotEmpty)
        Text(duration,
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
    ]);
  }
}

// ── Tab: Reviews ──────────────────────────────────────────────────────────────

class _ReviewsTab extends ConsumerWidget {
  final int courseId;
  const _ReviewsTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider(courseId));
    final theme = Theme.of(context);

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
          message: e.toString().replaceAll('Exception: ', '')),
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
              child: Text('لا توجد تقييمات بعد',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: review.authorAvatar.isNotEmpty
                ? CachedNetworkImageProvider(review.authorAvatar)
                : null,
            child: review.authorAvatar.isEmpty
                ? Text(review.authorName.isNotEmpty ? review.authorName[0] : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(review.authorName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Row(
                      children: List.generate(
                          5,
                          (i) => Icon(Icons.star_rounded,
                              size: 14,
                              color: i < review.rating.round()
                                  ? Colors.amber
                                  : theme.colorScheme.surfaceContainerHighest))),
                ]),
                const SizedBox(height: 4),
                Text(review.content, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Persistent TabBar ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
