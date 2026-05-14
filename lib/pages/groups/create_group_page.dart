import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../services/groups_service.dart';
import '../../providers/subscription_provider.dart';
import '../../models/feature_flags.dart';
import '../../services/badges_service.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/badge_unlocked_dialog.dart';
import '../../widgets/constrained_content.dart';
import 'select_club_cover_page.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupsService _groupsService = GroupsService();

  bool _isPrivate = false;
  bool _isCreating = false;
  String? _selectedCoverUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SelectClubCoverPage(
          currentCoverUrl: _selectedCoverUrl,
        ),
      ),
    );
    if (url != null && mounted) {
      setState(() => _selectedCoverUrl = url);
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      await _groupsService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverUrl: _selectedCoverUrl,
        isPrivate: _isPrivate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).groupCreated),
            backgroundColor: Colors.green,
          ),
        );

        // Vérifier si le badge "Fondateur de Club" est débloqué
        try {
          final newBadges = await BadgesService().checkAndAwardBadges();
          if (mounted && newBadges.isNotEmpty) {
            for (final badge in newBadges) {
              await showDialog(
                context: context,
                barrierDismissible: true,
                builder: (_) => BadgeUnlockedDialog(badge: badge),
              );
            }
          }
        } catch (e) {
          debugPrint('Erreur check badges après création club: $e');
        }

        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (!mounted) return;

      final errorMsg = e.toString();
      if (errorMsg.contains('Limite de')) {
        _showGroupLimitDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGroupLimitDialog() {
    final l = AppLocalizations.of(context);
    showPremiumUpsellSheet(
      context,
      feature: Feature.customLists,
      customMessage: l.groupLimitMessage(FeatureFlags.maxFreeGroups),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BackHeader(title: l.createGroupTitle),
                const SizedBox(height: AppSpace.l),

                // Cover image — picker depuis la bibliothèque curée
                Center(
                  child: GestureDetector(
                    onTap: _pickCover,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selectedCoverUrl != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: _selectedCoverUrl!,
                                  fit: BoxFit.cover,
                                  memCacheHeight: 240,
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: const Text(
                                      'Changer',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.primary,
                                  size: 40,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Choisir une couverture',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),

                // Group name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l.groupNameRequired,
                    hintText: l.groupNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 100,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l.nameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.m),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l.descriptionOptional,
                    hintText: l.describeGroup,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: AppSpace.m),

                // Privacy toggle
                Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(
                      color: _isPrivate
                          ? Colors.orange.withValues(alpha:0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPrivate ? Icons.lock : Icons.public,
                        color: _isPrivate ? Colors.orange : AppColors.primary,
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPrivate ? l.privateGroup : l.publicGroup,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isPrivate
                                  ? l.inviteOnly
                                  : l.visibleToAll,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPrivate,
                        onChanged: (value) => setState(() => _isPrivate = value),
                        activeThumbColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),

                // Info card
                Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Text(
                          l.creatorAdminInfo,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary.withValues(alpha:0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            l.createGroup,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
