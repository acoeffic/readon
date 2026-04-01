import 'package:flutter/material.dart';
import 'feed_skeleton_card.dart';

class FeedSkeletonList extends StatelessWidget {
  final int itemCount;
  const FeedSkeletonList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (_, __) => const FeedSkeletonCard(),
    );
  }
}
