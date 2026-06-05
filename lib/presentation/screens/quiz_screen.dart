import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/error_widget.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final int quizId;
  const QuizScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _started = false;

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startTimer(int totalSeconds) {
    if (totalSeconds <= 0) return;
    _remainingSeconds = totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 0) {
        t.cancel();
        _submit();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  int _totalSeconds(QuizData quiz) {
    if (quiz.timeLimit <= 0) return 0;
    switch (quiz.timeType) {
      case 'seconds': return quiz.timeLimit;
      case 'hours':   return quiz.timeLimit * 3600;
      case 'days':    return quiz.timeLimit * 86400;
      default:        return quiz.timeLimit * 60; // minutes
    }
  }

  String _formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }

  Future<void> _startQuiz(QuizData quiz) async {
    await ref.read(quizNotifierProvider(widget.quizId).notifier).startQuiz();
    final s = ref.read(quizNotifierProvider(widget.quizId));
    if (s.error != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!)));
      return;
    }
    setState(() => _started = true);
    _startTimer(_totalSeconds(quiz));
  }

  Future<void> _submit() async {
    _timer?.cancel();
    final result = await ref.read(quizNotifierProvider(widget.quizId).notifier).submitQuiz();
    if (result != null && mounted) _showResult(result);
  }

  void _showResult(QuizResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: Icon(
          result.isPass ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 64,
          color: result.isPass ? Colors.green : Colors.red,
        ),
        title: Text(result.isPass ? 'أحسنت! اجتزت الاختبار 🎉' : 'لم تجتز الاختبار',
            textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _ResultRow('درجتك',      '${result.earnedMarks.toStringAsFixed(1)} / ${result.totalMarks.toStringAsFixed(1)}'),
          _ResultRow('النسبة',     '${result.resultPercent.toStringAsFixed(1)}%'),
          _ResultRow('درجة النجاح','${result.passingGrade}%'),
        ]),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // quiz screen
            },
            child: const Text('العودة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizProvider(widget.quizId));
    final quizState = ref.watch(quizNotifierProvider(widget.quizId));
    final theme     = Theme.of(context);

    return quizAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(quizProvider(widget.quizId))),
      ),
      data: (quiz) {
        // صفحة البداية
        if (!_started) return _StartPage(quiz: quiz, onStart: () => _startQuiz(quiz));

        final questions = quiz.questions;
        if (questions.isEmpty) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('لا توجد أسئلة')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(quiz.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            centerTitle: true,
            actions: [
              if (_remainingSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _remainingSeconds < 60
                            ? Colors.red.withValues(alpha: 0.15)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.timer_outlined, size: 16,
                            color: _remainingSeconds < 60 ? Colors.red : theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(_formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _remainingSeconds < 60 ? Colors.red : theme.colorScheme.primary,
                            )),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(children: [
            // ── Progress bar ───────────────────────────────────────────
            LinearProgressIndicator(
              value: (_currentPage + 1) / questions.length,
              minHeight: 4,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text('سؤال ${_currentPage + 1} من ${questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${quizState.selectedAnswers.length} مجاب',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
              ]),
            ),
            const Divider(height: 1),

            // ── Questions ──────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _QuestionPage(
                  question:  questions[i],
                  quizId:    widget.quizId,
                  quizState: quizState,
                ),
              ),
            ),

            // ── Navigation ─────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  if (_currentPage > 0)
                    OutlinedButton.icon(
                      onPressed: () {
                        _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('السابق'),
                    ),
                  const Spacer(),
                  if (_currentPage < questions.length - 1)
                    FilledButton.icon(
                      onPressed: () {
                        _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      label: const Text('التالي'),
                      icon: const Icon(Icons.chevron_left_rounded),
                    )
                  else
                    FilledButton.icon(
                      onPressed: quizState.isSubmitting ? null : _submit,
                      icon: quizState.isSubmitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                      label: Text(quizState.isSubmitting ? 'جارٍ التسليم...' : 'تسليم الاختبار'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Start Page ────────────────────────────────────────────────────────────────

class _StartPage extends StatelessWidget {
  final QuizData quiz;
  final VoidCallback onStart;
  const _StartPage({required this.quiz, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(quiz.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.quiz_rounded, size: 44, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(quiz.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),

          _InfoCard(children: [
            _InfoRow(Icons.help_outline_rounded,        'عدد الأسئلة',   '${quiz.questions.length} سؤال'),
            if (quiz.timeLimit > 0)
              _InfoRow(Icons.timer_outlined,            'الوقت المحدد',  '${quiz.timeLimit} ${_typeLabel(quiz.timeType)}'),
            _InfoRow(Icons.check_circle_outline_rounded,'درجة النجاح',   '${quiz.passingGrade}%'),
            if (quiz.maxAttempts > 0)
              _InfoRow(Icons.repeat_rounded,            'عدد المحاولات', '${quiz.attemptCount} / ${quiz.maxAttempts}'),
          ]),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (quiz.maxAttempts > 0 && quiz.attemptCount >= quiz.maxAttempts) ? null : onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                quiz.maxAttempts > 0 && quiz.attemptCount >= quiz.maxAttempts
                    ? 'استنفدت المحاولات'
                    : 'ابدأ الاختبار',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'seconds': return 'ثانية';
      case 'hours':   return 'ساعة';
      case 'days':    return 'يوم';
      default:        return 'دقيقة';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── Question Page ─────────────────────────────────────────────────────────────

class _QuestionPage extends ConsumerWidget {
  final QuizQuestion question;
  final int quizId;
  final QuizState quizState;
  const _QuestionPage({required this.question, required this.quizId, required this.quizState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme    = Theme.of(context);
    final notifier = ref.read(quizNotifierProvider(quizId).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Question title ─────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(question.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.6)),
        ),
        if (question.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(question.description,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.6)),
        ],
        const SizedBox(height: 20),

        // ── Answers ────────────────────────────────────────────────────
        if (question.type == 'single_choice' || question.type == 'true_false')
          ...question.answers.map((a) {
            final selected = quizState.selectedAnswers[question.id] == a.id;
            return _AnswerTile(
              title: a.title, selected: selected,
              onTap: () => notifier.selectAnswer(question.id, a.id),
            );
          })
        else if (question.type == 'multiple_choice')
          ...question.answers.map((a) {
            final list    = quizState.selectedAnswers[question.id] as List? ?? [];
            final selected= list.contains(a.id);
            return _AnswerTile(
              title: a.title, selected: selected, isCheckbox: true,
              onTap: () => notifier.toggleMultiAnswer(question.id, a.id),
            );
          })
        else if (question.type == 'open_ended' || question.type == 'short_answer')
          TextField(
            maxLines: question.type == 'open_ended' ? 5 : 2,
            onChanged: (v) => notifier.selectAnswer(question.id, v),
            decoration: InputDecoration(
              hintText: 'اكتب إجابتك هنا...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          )
        else if (question.type == 'fill_in_the_blank')
          TextField(
            onChanged: (v) => notifier.selectAnswer(question.id, v),
            decoration: InputDecoration(
              hintText: 'أكمل الفراغ...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.edit_outlined),
              filled: true,
            ),
          )
        else
          Text('نوع السؤال: ${question.type}',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String title;
  final bool selected;
  final bool isCheckbox;
  final VoidCallback onTap;
  const _AnswerTile({required this.title, required this.selected,
      this.isCheckbox = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            isCheckbox
                ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? theme.colorScheme.primary : null,
          ))),
        ]),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      );
}
