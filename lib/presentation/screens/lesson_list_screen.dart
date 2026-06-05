import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/failures.dart';
import '../../core/widgets/error_widget.dart';
import '../../domain/entities/lesson.dart';
import '../providers/courses_provider.dart';
import '../providers/di_providers.dart';

class LessonListScreen extends ConsumerWidget {
  final int courseId;
  const LessonListScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(courseId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('محتوى الدورة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          if (error is EnrollmentFailure) {
            return _EnrollmentGate(
              courseId: error.courseId > 0 ? error.courseId : courseId,
              message:  error.message,
              onEnrolled: () => ref.invalidate(topicsProvider(courseId)),
            );
          }
          return AppErrorWidget(
            message: error.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(topicsProvider(courseId)),
          );
        },
        data: (topics) {
          if (topics.isEmpty) {
            return Center(
              child: Text('لا يوجد محتوى متاح',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            );
          }

          final allEntries = <_LessonEntry>[];
          for (final topic in topics) {
            allEntries.add(_LessonEntry.topic(topic));
            for (final lesson in topic.lessons) {
              allEntries.add(_LessonEntry.lesson(lesson, topic.id));
            }
          }

          // ✅ التغيير: نجمع كل الدروس التي لها فيديو لتمريرها للمشغل
          // المشغل النيتف يحتاجها كلها لخاصية "التالي / السابق"
          final allVideoLessons = allEntries
              .where((e) => !e.isTopic && e.lesson!.hasVideo)
              .map((e) => e.lesson!)
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: allEntries.length,
            itemBuilder: (_, i) {
              final entry = allEntries[i];
              if (entry.isTopic) {
                return _TopicHeader(topic: entry.topic!);
              }
              return _LessonTile(
                lesson: entry.lesson!,
                onTap: () {
                  final l = entry.lesson!;

                  if (l.isQuiz) {
                    // ── اختبار إلكتروني
                    context.push('/quiz/${l.id}');

                  } else if (l.hasVideo) {
                    // ── درس فيديو → المشغل النيتف المستقل
                    // extra['allLessons'] يحتوي الآن على كل دروس الفيديو
                    // حتى يتمكن المشغل من التنقل بينها بدون العودة لهذه الشاشة
                    context.push(
                      '/video/${l.id}',
                      extra: {
                        'lesson':     l,
                        'courseId':   courseId,
                        'allLessons': allVideoLessons, // ✅ كل دروس الفيديو
                      },
                    );

                  } else {
                    // ── درس نصي / PDF / واجب
                    context.push(
                      '/lesson-web/${l.id}',
                      extra: {'title': l.title},
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ── Enrollment Gate ───────────────────────────────────────────────────────────

class _EnrollmentGate extends ConsumerStatefulWidget {
  final int courseId;
  final String message;
  final VoidCallback onEnrolled;

  const _EnrollmentGate({
    required this.courseId,
    required this.message,
    required this.onEnrolled,
  });

  @override
  ConsumerState<_EnrollmentGate> createState() => _EnrollmentGateState();
}

class _EnrollmentGateState extends ConsumerState<_EnrollmentGate> {
  bool _loading = false;
  String? _error;

  Future<void> _enroll() async {
    setState(() { _loading = true; _error = null; });

    final result = await ref
        .read(enrollCourseUseCaseProvider)
        .call(widget.courseId);

    if (!mounted) return;

    result.fold(
      (f) => setState(() { _loading = false; _error = f.message; }),
      (_) {
        setState(() => _loading = false);
        widget.onEnrolled();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'محتوى حصري',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _enroll,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.school_rounded),
                label: Text(_loading ? 'جارٍ التسجيل...' : 'سجّل في الدورة الآن'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LessonEntry {
  final bool isTopic;
  final Topic? topic;
  final Lesson? lesson;
  final int? topicId;

  const _LessonEntry.topic(this.topic)
      : isTopic = true, lesson = null, topicId = null;

  const _LessonEntry.lesson(this.lesson, this.topicId)
      : isTopic = false, topic = null;
}

class _TopicHeader extends StatelessWidget {
  final Topic topic;
  const _TopicHeader({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(children: [
        Icon(Icons.folder_open_rounded,
            color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(topic.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface)),
        ),
        Text('${topic.lessons.length} درس',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  const _LessonTile({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: lesson.isCompleted
              ? Colors.green.withValues(alpha: 0.1)
              : theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          lesson.isCompleted
              ? Icons.check_rounded
              : lesson.isQuiz
                  ? Icons.quiz_rounded
                  : lesson.isAssignment
                      ? Icons.assignment_outlined
                      : lesson.hasVideo
                          ? Icons.play_arrow_rounded
                          : Icons.article_outlined,
          color: lesson.isCompleted ? Colors.green : theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        lesson.title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: lesson.isCompleted ? TextDecoration.lineThrough : null,
          color: lesson.isCompleted
              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
              : null,
        ),
      ),
      subtitle: lesson.videoDuration.isNotEmpty
          ? Text(lesson.videoDuration,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)))
          : null,
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}
