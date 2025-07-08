import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget playerShimmer(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;

  return Container(
    color: scheme.surfaceContainerHighest.withAlpha((256 * 0.2).toInt()),
    alignment: Alignment.center,
    child: Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withAlpha((256 * 0.3).toInt()),
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Shimmer.fromColors(
          baseColor: scheme.onSurfaceVariant.withAlpha((256 * 0.6).toInt()),
          highlightColor: scheme.surfaceContainerHighest.withAlpha(
            (256 * 0.8).toInt(),
          ),
          period: const Duration(seconds: 2),
          child: Icon(
            Icons.play_arrow,
            size: 36,
            color: scheme.onSurfaceVariant.withAlpha((256 * 0.7).toInt()),
          ),
        ),
      ),
    ),
  );
}

Widget movieInfoShimmer(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;

  return Expanded(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest.withAlpha(
          (256 * 0.4).toInt(),
        ),
        highlightColor: scheme.primary.withAlpha((256 * 0.3).toInt()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Poster shimmer
                Container(
                  height: 150,
                  width: 100,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                // Title + rating + plot shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: 180,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 140,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 48,
              width: 200,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
