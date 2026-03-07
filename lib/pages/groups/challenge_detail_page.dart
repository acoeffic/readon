import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
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
            SnackBar(content: Text(AppLocalizations.of(context).leftChallenge)),
          );
        }
      } else {
        await _challengeService.joinChallenge(widget.challenge.id);
        setState(() => _userJoined = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).joinedChallenge),
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
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.deleteChallengeTitle),
        content: Text(l.deleteChallengeMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.deleteButton,
              style: const TextStyle(color: AppColors.error),
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
          SnackBar(
            content: Text(AppLocalizations.of(context).challengeDeleted),
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

  String _formatTimeRemaining(BuildContext context, Duration duration) {
    final l = AppLocalizations.of(context);
    if (duration.isNegative) return l.expired;
    if (duration.inDays > 0) {
      return l.daysRemaining(duration.inDays);
    } else if (duration.inHours > 0) {
      return l.hoursRemaining(duration.inHours);
    } else {
      return l.minutesRemaining(duration.inMinutes);
    }
  }

  String _getTargetDescription(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (widget.challenge.type) {
      case 'read_book':
        return widget.challenge.targetBookTitle ?? l.readABook;
      case 'read_pages':
        return l.pagesToRead(widget.challenge.targetValue);
      case 'read_daily':
        return l.dailyChallenge(widget.challenge.targetValue, widget.challenge.targetDays ?? 7);
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
    final l = AppLocalizations.of(context);
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
                  Expanded(
                    child: Center(
                      child: Text(
                        l.challengeDetail,
                        style: const TextStyle(
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
                                  color: AppColors.primary.withValues(alpha:0.1),
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
                                            ? Colors.green.withValues(alpha:0.1)
                                            : Colors.red.withValues(alpha:0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        challenge.isActive
                                            ? _formatTimeRemaining(context, challenge.timeRemaining)
                                            : l.expired,
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
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpace.m),
                          const Divider(),
                          const SizedBox(height: AppSpace.s),
                          Row(
                            children: [
                              Icon(Icons.flag, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              const SizedBox(width: 8),
                              Text(
                                _getTargetDescription(context),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      _buildProgressCard(context, challenge),
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
                                  _userJoined ? l.leaveChallenge : l.joinChallenge,
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
                      l.participantsCount(_participants.length),
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
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                l.noParticipants,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...(_participants.map((p) => _buildParticipantTile(context, p, challenge))),

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

  Widget _buildProgressCard(BuildContext context, GroupChallenge challenge) {
    final l = AppLocalizations.of(context);
    final progress = challenge.userProgress ?? 0;
    final percent = challenge.progressPercent;

    String progressLabel;
    switch (challenge.type) {
      case 'read_book':
        progressLabel = challenge.userCompleted ? l.challengeCompleted : l.challengeInProgress;
        break;
      case 'read_pages':
        progressLabel = l.progressPages(progress, challenge.targetValue);
        break;
      case 'read_daily':
        progressLabel = l.progressDays(progress, challenge.targetDays ?? 7);
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
              Text(
                l.myProgress,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (challenge.userCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.completedTag,
                    style: const TextStyle(
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
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(BuildContext context, ChallengeParticipant participant, GroupChallenge challenge) {
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
              backgroundColor: AppColors.primary.withValues(alpha:0.1),
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
                      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
