import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bundle_model.dart';
import '../../domain/entities/bundle.dart';
import '../providers/bundles_provider.dart';

// ── Provider خاص لجلب حزمة واحدة ─────────────────────────────────────────────

final singleBundleProvider = FutureProvider.autoDispose
    .family<Bundle, int>((ref, bundleId) async {
  // أولاً: ابحث في الـ cache
  final cached = ref.read(bundlesProvider).bundles
      .where((b) => b.id == bundleId)
      .firstOrNull;
  if (cached != null && cached.courses.isNotEmpty) return cached;

  // ثانياً: اطلب من الـ API مباشرة
  final response = await DioClient.instance.dio
      .get(ApiConstants.bundleEndpoint(bundleId));
  final data = response.data as Map<String, dynamic>;
  final raw  = data['data'] as Map<String, dynamic>? ?? data;
  return BundleModel.fromJson(raw);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class BundleDetailScreen extends ConsumerWidget {
  final int bundleId;
  const BundleDetailScreen({super.key, required this.bundleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(singleBundleProvider(bundleId));

    return async.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.sage100,
        appBar: AppBar(
          backgroundColor: AppTheme.mocha500,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.coral500),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.sage100,
        appBar: AppBar(
          backgroundColor: AppTheme.mocha500,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 56, color: AppTheme.sage500),
                const SizedBox(height: 16),
                Text(
                  'تعذّر تحميل الحزمة\nتحقق من اتصالك وحاول مجدداً',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(singleBundleProvider(bundleId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.mocha500),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (bundle) => _BundleDetailView(bundle: bundle),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class _BundleDetailView extends ConsumerWidget {
  final Bundle bundle;
  const _BundleDetailView({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.sage100,
      body: CustomScrollView(
        slivers: [

          // ── SliverAppBar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.mocha500,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(right: 16, left: 56, bottom: 14),
              title: Text(
                bundle.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail
                  bundle.thumbnail.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: bundle.thumbnail,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                  gradient: AppTheme.headerGradient)),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                              gradient: AppTheme.headerGradient)),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.mocha900.withValues(alpha: 0.88),
                        ],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),
                  // Enrolled badge top-left
                  if (bundle.isEnrolled)
                    Positioned(
                      top: 52, left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                size: 13, color: Colors.white),
                            SizedBox(width: 5),
                            Text('مسجّل',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Info + Action ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.sage300),
                    ),
                    child: Row(children: [
                      _Stat(
                        icon: Icons.library_books_outlined,
                        label: '${bundle.courseCount} دورة',
                      ),
                      Container(
                        width: 1, height: 32, color: AppTheme.sage300,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      _Stat(
                        icon: bundle.isEnrolled
                            ? Icons.check_circle_outline_rounded
                            : Icons.vpn_key_outlined,
                        label: bundle.isEnrolled ? 'مسجّل' : 'يتطلب كود',
                        color: bundle.isEnrolled
                            ? AppTheme.success
                            : AppTheme.textMuted,
                      ),
                    ]),
                  ),

                  // Description
                  if (bundle.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.sage300),
                      ),
                      child: Text(
                        bundle.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMid,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── CTA Button ────────────────────────────────────────
                  if (!bundle.isEnrolled) ...[
                    _BundleCodeButton(bundle: bundle),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'كود الحزمة يُسجّلك في جميع الدورات دفعةً واحدة',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ] else
                    _EnrolledBanner(),

                  const SizedBox(height: 24),

                  // ── Courses header ────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 4, height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.coral500,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'الدورات المضمّنة (${bundle.courseCount})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mocha700,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ── Courses list ──────────────────────────────────────────────
          bundle.courses.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    child: Center(
                      child: Text('لا توجد دورات في هذه الحزمة',
                          style: const TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _CourseRow(
                        course: bundle.courses[i],
                        bundleId: bundle.id,
                        bundleIsEnrolled: bundle.isEnrolled,
                        index: i,
                      ),
                      childCount: bundle.courses.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Stat({
    required this.icon,
    required this.label,
    this.color = AppTheme.mocha500,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
}

class _BundleCodeButton extends StatelessWidget {
  final Bundle bundle;
  const _BundleCodeButton({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mocha500.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(
            '/redeem-code',
            extra: {
              'bundle_id':    bundle.id,
              'bundle_title': bundle.title,
              'content_type': 'bundle',
              'course_id':    0,
              'course_title': '',
            },
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'أدخل كود الحزمة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnrolledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded,
            color: AppTheme.success, size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('أنت مسجّل في هذه الحزمة',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
        ),
        GestureDetector(
          onTap: () => context.push('/my-courses'),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('ابدأ التعلم',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final BundleCourse course;
  final int          bundleId;
  final bool         bundleIsEnrolled;
  final int          index;

  const _CourseRow({
    required this.course,
    required this.bundleId,
    required this.bundleIsEnrolled,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final enrolled = course.isEnrolled;
    final gradColors =
        AppTheme.categoryGradients[index % AppTheme.categoryGradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enrolled
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.sage300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enrolled
              ? () => context.push('/lessons/${course.id}')
              : () => context.push(
                    '/redeem-code',
                    extra: {
                      'bundle_id':    bundleId,
                      'bundle_title': '',
                      'content_type': 'course',
                      'course_id':    course.id,
                      'course_title': course.title,
                    },
                  ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // رقم الدورة
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: course.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: course.thumbnail,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _ThumbPlaceholder(colors: gradColors),
                          )
                        : _ThumbPlaceholder(colors: gradColors),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: enrolled
                              ? AppTheme.mocha700
                              : AppTheme.textMid,
                        ),
                      ),
                      const SizedBox(height: 6),
                      enrolled
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppTheme.success),
                              const SizedBox(width: 4),
                              const Text('مسجّل — اضغط للبدء',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w600)),
                            ])
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.vpn_key_outlined,
                                  size: 14, color: AppTheme.coral500),
                              const SizedBox(width: 4),
                              Text('أدخل كود الدورة',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.coral500,
                                      fontWeight: FontWeight.w600)),
                            ]),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  enrolled
                      ? Icons.play_circle_filled_rounded
                      : Icons.keyboard_arrow_left_rounded,
                  color: enrolled
                      ? AppTheme.success
                      : AppTheme.sage500,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  final List<Color> colors;
  const _ThumbPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.play_circle_outline_rounded,
            color: Colors.white54, size: 28),
      );
}
