// pages/feed/widgets/progress_card.dart
// Card pour afficher la progression de lecture

import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final String bookTitle;
  final String author;
  final double progress;
  final int? currentPage;
  final int? totalPages;
  final int? pagesRead;

  const ProgressCard({
    super.key,
    required this.bookTitle,
    required this.author,
    required this.progress,
    this.currentPage,
    this.totalPages,
    this.pagesRead,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre et auteur
            Text(
              bookTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              author,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Infos de progression
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentPage != null && totalPages != null)
                  Text(
                    'Page $currentPage / $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                if (pagesRead != null && pagesRead! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '+$pagesRead page${pagesRead! > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}