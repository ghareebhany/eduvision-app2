import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppLoadingWidget extends StatelessWidget {
  final int itemCount;
  const AppLoadingWidget({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          // FIX: surfaceVariant → surfaceContainerHighest
          baseColor: cs.surfaceContainerHighest,
          highlightColor: cs.surface,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
