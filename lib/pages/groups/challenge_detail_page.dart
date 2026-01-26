import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../models/group_challenge.dart';
import '../../services/challenge_service.dart';

class ChallengeDetailPage extends StatefulWidget {
  final GroupChallenge challenge;
  final bool isAdmin;

  const ChallengeDetailPage({
    super.key,
    required this.challenge,
    this.isAdmin = false,
  });

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  final ChallengeService _challengeService = ChallengeService();

  List<ChallengeParticipant> _participants = [];
  bool _isLoading = true;
  bool _userJoined = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _userJoined = widget.challenge.userJoined;
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    try {
      final participants = await _challengeService.getParticipants(widget.challenge.id);
      setState(() {
        _participants = participants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleParticipation() async {
    setState(() => _isJoining = true);
    try {
      if (_userJoined) {
        await _challengeService.leaveChallenge(widget.challenge.id);
        setState(() => _userJoined = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous avez quitté le défi')),
          );
        }
      } else {
        await _challengeService.joinChallenge(widget.challenge.id);
        setState(() => _userJoined = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vous participez au défi !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      _loadParticipants();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isJoining = false);
    }
  }

  Future<void> _deleteChallenge() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Supprimer le défi ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _challengeService.deleteChallenge(widget.challenge.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Défi supprimé'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return 'Expiré';
    if (duration.inDays > 0) {
      return '${duration.inDays}j restants';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h restantes';
    } else {
      return '${duration.inMinutes}min restantes';
    }
  }

  String _getTargetDescription() {
    switch (widget.challenge.type) {
      case 'read_book':
        return widget.challenge.targetBookTitle ?? 'Lire un livre';
      case 'read_pages':
        return '${widget.challenge.targetValue} pages à lire';
      case 'read_daily':
        return '${widget.challenge.targetValue} min/jour pendant ${widget.challenge.targetDays} jours';
      default:
        return '';
    }
  }

  IconData _getTypeIcon() {
    switch (widget.challenge.type) {
      case 'read_book':
        return Icons.book;
      case 'read_pages':
        return Icons.menu_book;
      case 'read_daily':
        return Icons.calendar_today;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Détail du défi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (widget.isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: _deleteChallenge,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Challenge header card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.l),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.m),
                                ),
                                child: Icon(
                                  _getTypeIcon(),
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: AppSpace.m),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      challenge.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: challenge.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        challenge.isActive
                                            ? _formatTimeRemaining(challenge.timeRemaining)
                                            : 'Expiré',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: challenge.isActive
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (challenge.description != null) ...[
                            const SizedBox(height: AppSpace.m),
                            Text(
                              challenge.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpace.m),
                          const Divider(),
                          const SizedBox(height: AppSpace.s),
                          Row(
                            children: [
                              Icon(Icons.flag, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                _getTargetDescription(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.l),

                    // User progress (if joined)
                    if (_userJoined) ...[
                      _buildProgressCard(challenge),
                      const SizedBox(height: AppSpace.l),
                    ],

                    // Join/Leave button
                    if (challenge.isActive)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isJoining ? null : _toggleParticipation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _userJoined
                                ? Colors.grey.shade700
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _userJoined ? 'Quitter le défi' : 'Rejoindre le défi',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.xl),

                    // Participants section
                    Text(
                      'Participants (${_participants.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpace.m),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_participants.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                'Aucun participant',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...(_participants.map((p) => _buildParticipantTile(p, challenge))),

                    const SizedBox(height: AppSpace.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(GroupChallenge challenge) {
    final progress = challenge.userProgress ?? 0;
    final percent = challenge.progressPercent;

    String progressLabel;
    switch (challenge.type) {
      case 'read_book':
        progressLabel = challenge.userCompleted ? 'Terminé !' : 'En cours...';
        break;
      case 'read_pages':
        progressLabel = '$progress / ${challenge.targetValue} pages';
        break;
      case 'read_daily':
        progressLabel = '$progress / ${challenge.targetDays ?? 7} jours';
        break;
      default:
        progressLabel = '$progress';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ma progression',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (challenge.userCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Complété',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.userCompleted ? Colors.green : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progressLabel,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(ChallengeParticipant participant, GroupChallenge challenge) {
    double percent;
    if (challenge.type == 'read_daily') {
      final target = challenge.targetDays ?? 7;
      percent = target > 0 ? (participant.progress / target).clamp(0.0, 1.0) : 0;
    } else {
      percent = challenge.targetValue > 0
          ? (participant.progress / challenge.targetValue).clamp(0.0, 1.0)
          : 0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.s),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: participant.userAvatar != null
                  ? NetworkImage(participant.userAvatar!)
                  : null,
              child: participant.userAvatar == null
                  ? Text(
                      participant.displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        participant.completed ? Colors.green : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.m),
            if (participant.completed)
              const Icon(Icons.check_circle, color: Colors.green, size: 20)
            else
              Text(
                '${(percent * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
