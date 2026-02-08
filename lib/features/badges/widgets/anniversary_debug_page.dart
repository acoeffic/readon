// lib/features/badges/widgets/anniversary_debug_page.dart
// Page de test temporaire — à supprimer avant la mise en production

import 'package:flutter/material.dart';
import '../models/anniversary_badge.dart';
import '../services/anniversary_service.dart';
import 'anniversary_unlock_overlay.dart';

class AnniversaryDebugPage extends StatefulWidget {
  const AnniversaryDebugPage({super.key});

  @override
  State<AnniversaryDebugPage> createState() => _AnniversaryDebugPageState();
}

class _AnniversaryDebugPageState extends State<AnniversaryDebugPage> {
  final _anniversaryService = AnniversaryService();
  AnniversaryStats? _realStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _anniversaryService.getAnniversaryStats();
    if (mounted) {
      setState(() {
        _realStats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Badges Anniversaire'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Appuie sur un badge pour lancer l\'animation complète.\nLes stats affichées sont tes vraies données (12 derniers mois).',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),

                // Aperçu des vraies stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatPreview(
                          emoji: '📚', value: '${_realStats!.booksFinished}'),
                      _StatPreview(
                          emoji: '⏱', value: '${_realStats!.hoursRead}h'),
                      _StatPreview(
                          emoji: '🔥', value: '${_realStats!.bestFlow}j'),
                      _StatPreview(
                          emoji: '💬', value: '${_realStats!.commentsCount}'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                ...AnniversaryBadge.all.map((badge) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: badge.primaryColor, width: 1.5),
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badge.primaryColor.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Text(badge.icon,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        title: Text(
                          badge.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${badge.years} an${badge.years > 1 ? 's' : ''}'
                          '${badge.isPremium ? ' · Premium' : ''}',
                        ),
                        trailing: Icon(Icons.play_arrow,
                            color: badge.primaryColor, size: 28),
                        onTap: () => AnniversaryUnlockOverlay.show(
                          context,
                          badge: badge,
                          stats: _realStats!,
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _StatPreview extends StatelessWidget {
  final String emoji;
  final String value;

  const _StatPreview({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
