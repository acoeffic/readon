import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FeedSkeletonCard extends StatelessWidget {
  const FeedSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE8E0D4);
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF5EFE7);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header : avatar + nom + temps
            Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Nom + horodatage
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 13, color: Colors.white, margin: const EdgeInsets.only(bottom: 6)),
                    Container(width: 70, height: 11, color: Colors.white),
                  ],
                ),
                const Spacer(),
                // Badge / action
                Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ],
            ),
            const SizedBox(height: 14),
            // Ligne de texte principale (ex: "a lu X pages de…")
            Container(width: double.infinity, height: 13, color: Colors.white, margin: const EdgeInsets.only(bottom: 8)),
            Container(width: 180, height: 13, color: Colors.white),
            const SizedBox(height: 14),
            // Vignette livre + infos
            Row(
              children: [
                Container(
                  width: 52,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 140, height: 13, color: Colors.white, margin: const EdgeInsets.only(bottom: 6)),
                    Container(width: 100, height: 11, color: Colors.white, margin: const EdgeInsets.only(bottom: 6)),
                    Container(width: 80, height: 11, color: Colors.white),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Barre de progression
            Container(
              width: double.infinity, height: 8,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
}
