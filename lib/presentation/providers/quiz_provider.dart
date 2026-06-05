import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

// ── Entities ──────────────────────────────────────────────────────────────────

class QuizAnswer {
  final int id;
  final String title;
  final String imageUrl;
  final String viewFormat;
  const QuizAnswer({required this.id, required this.title, this.imageUrl = '', this.viewFormat = 'text'});

  factory QuizAnswer.fromJson(Map<String, dynamic> j) => QuizAnswer(
        id:         j['id']          as int,
        title:      j['title']       as String? ?? '',
        imageUrl:   j['image_url']   as String? ?? '',
        viewFormat: j['view_format'] as String? ?? 'text',
      );
}

class QuizQuestion {
  final int id;
  final String title;
  final String description;
  final String type;
  final double mark;
  final List<QuizAnswer> answers;
  const QuizQuestion({required this.id, required this.title, required this.description,
      required this.type, required this.mark, required this.answers});

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id:          j['id']          as int,
        title:       j['title']       as String? ?? '',
        description: j['description'] as String? ?? '',
        type:        j['type']        as String? ?? 'single_choice',
        mark:        (j['mark'] as num?)?.toDouble() ?? 1.0,
        answers: (j['answers'] as List? ?? [])
            .map((a) => QuizAnswer.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class QuizData {
  final int id;
  final String title;
  final int courseId;
  final int passingGrade;
  final int timeLimit;
  final String timeType;
  final int maxAttempts;
  final int attemptCount;
  final String feedbackMode;
  final List<QuizQuestion> questions;
  const QuizData({required this.id, required this.title, required this.courseId,
      required this.passingGrade, required this.timeLimit, required this.timeType,
      required this.maxAttempts, required this.attemptCount, required this.feedbackMode,
      required this.questions});

  factory QuizData.fromJson(Map<String, dynamic> j) => QuizData(
        id:            j['id']             as int,
        title:         j['title']          as String? ?? '',
        courseId:      j['course_id']      as int,
        passingGrade:  j['passing_grade']  as int? ?? 80,
        timeLimit:     j['time_limit']     as int? ?? 0,
        timeType:      j['time_type']      as String? ?? 'minutes',
        maxAttempts:   j['max_attempts']   as int? ?? 0,
        attemptCount:  j['attempt_count']  as int? ?? 0,
        feedbackMode:  j['feedback_mode']  as String? ?? 'default',
        questions: (j['questions'] as List? ?? [])
            .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class QuizResult {
  final int attemptId;
  final double earnedMarks;
  final double totalMarks;
  final double resultPercent;
  final int passingGrade;
  final bool isPass;
  const QuizResult({required this.attemptId, required this.earnedMarks,
      required this.totalMarks, required this.resultPercent,
      required this.passingGrade, required this.isPass});

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        attemptId:     j['attempt_id']     as int? ?? 0,
        earnedMarks:   (j['earned_marks']  as num?)?.toDouble()  ?? 0.0,
        totalMarks:    (j['total_marks']   as num?)?.toDouble()  ?? 0.0,
        resultPercent: (j['result_percent'] as num?)?.toDouble() ?? 0.0,
        passingGrade:  j['passing_grade']  as int?  ?? 80,
        isPass:        j['is_pass']        as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final quizProvider = FutureProvider.family<QuizData, int>((ref, quizId) async {
  final res = await DioClient.instance.dio.get('/app/v1/quiz/$quizId');
  final body = res.data as Map<String, dynamic>;
  return QuizData.fromJson(body['data'] as Map<String, dynamic>);
});

// State للـ quiz أثناء الحل
class QuizState {
  final int? attemptId;
  final Map<int, dynamic> selectedAnswers; // questionId → answer
  final bool isSubmitting;
  final QuizResult? result;
  final String? error;

  const QuizState({this.attemptId, this.selectedAnswers = const {},
      this.isSubmitting = false, this.result, this.error});

  QuizState copyWith({int? attemptId, Map<int, dynamic>? selectedAnswers,
      bool? isSubmitting, QuizResult? result, String? error}) =>
      QuizState(
        attemptId:       attemptId       ?? this.attemptId,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitting:    isSubmitting    ?? this.isSubmitting,
        result:          result          ?? this.result,
        error:           error,
      );
}

class QuizNotifier extends StateNotifier<QuizState> {
  final int quizId;
  QuizNotifier(this.quizId) : super(const QuizState());

  final Dio _dio = DioClient.instance.dio;

  Future<void> startQuiz() async {
    try {
      final res = await _dio.post('/app/v1/quiz/$quizId/start');
      final body = res.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      state = state.copyWith(attemptId: data['attempt_id'] as int);
    } on DioException catch (e) {
      final body = e.response?.data;
      state = state.copyWith(error: (body is Map ? body['message'] : null) as String? ?? 'تعذّر بدء الاختبار');
    }
  }

  void selectAnswer(int questionId, dynamic answer) {
    final updated = Map<int, dynamic>.from(state.selectedAnswers);
    updated[questionId] = answer;
    state = state.copyWith(selectedAnswers: updated);
  }

  void toggleMultiAnswer(int questionId, int answerId) {
    final updated = Map<int, dynamic>.from(state.selectedAnswers);
    final current = List<int>.from(updated[questionId] as List? ?? []);
    if (current.contains(answerId)) {
      current.remove(answerId);
    } else {
      current.add(answerId);
    }
    updated[questionId] = current;
    state = state.copyWith(selectedAnswers: updated);
  }

  Future<QuizResult?> submitQuiz() async {
    if (state.attemptId == null) return null;
    state = state.copyWith(isSubmitting: true);

    final answers = state.selectedAnswers.entries.map((e) =>
        {'question_id': e.key, 'answer': e.value}).toList();

    try {
      final res = await _dio.post('/app/v1/quiz/$quizId/submit',
          data: {'attempt_id': state.attemptId, 'answers': answers});
      final body = res.data as Map<String, dynamic>;
      final result = QuizResult.fromJson(body['data'] as Map<String, dynamic>);
      state = state.copyWith(isSubmitting: false, result: result);
      return result;
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = (body is Map ? body['message'] : null) as String? ?? 'تعذّر تسليم الاختبار';
      state = state.copyWith(isSubmitting: false, error: msg);
      return null;
    }
  }
}

final quizNotifierProvider =
    StateNotifierProvider.family<QuizNotifier, QuizState, int>(
  (ref, quizId) => QuizNotifier(quizId),
);
