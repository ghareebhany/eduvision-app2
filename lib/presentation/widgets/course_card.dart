import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/course.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const CourseCard({super.key, required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.sage300),
          boxShadow: [
            BoxShadow(
              color: AppTheme.mocha500.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(children: [
                if (course.thumbnail.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: course.thumbnail,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: AppTheme.sage300,
                      highlightColor: AppTheme.sage100,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.mocha100,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 36, color: AppTheme.mocha400),
                    ),
                  )
                else
                  Container(
                    color: AppTheme.mocha100,
                    child: const Center(
                      child: Icon(Icons.play_circle_outline,
                          size: 44, color: AppTheme.mocha400),
                    ),
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13, height: 1.35,
                        color: AppTheme.mocha700),
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        course.instructorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _StatChip(icon: Icons.star_rounded,
                        label: course.rating.toStringAsFixed(1),
                        color: AppTheme.warning),
                    const SizedBox(width: 6),
                    _StatChip(icon: Icons.menu_book_outlined,
                        label: '${course.totalLessons}',
                        color: AppTheme.coral500),
                    const Spacer(),
                    _PriceChip(course: course),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11,
          color: color, fontWeight: FontWeight.w600)),
    ],
  );
}

class _PriceChip extends StatelessWidget {
  final Course course;
  const _PriceChip({required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.successLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        ),
        child: const Text('مجاني',
            style: TextStyle(color: AppTheme.success,
                fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.mocha50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.mocha200),
      ),
      child: Text(course.price,
          style: const TextStyle(color: AppTheme.mocha500,
              fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
