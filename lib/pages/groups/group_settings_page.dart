import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';
import 'group_members_page.dart';
import '../../widgets/constrained_content.dart';

const _kBg = Color(0xFFFAF3E8);
const _kCard = Color(0xFFF0E8D8);
const _kSageGreen = Color(0xFF6B988D);
const _kGold = Color(0xFFC6A85A);

class GroupSettingsPage extends StatefulWidget {
  final ReadingGroup group;

  const GroupSettingsPage({super.key, required this.group});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final GroupsService _groupsService = GroupsService();
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _isPrivate;

  bool _isSaving = false;
  bool _isUploadingCover = false;
  bool _isDeleting = false;
  bool _hasChanges = false;
  String? _currentCoverUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(text: widget.group.description ?? '');
    _isPrivate = widget.group.isPrivate;
    _currentCoverUrl = widget.group.coverUrl;

    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final nameChanged = _nameController.text.trim() != widget.group.name;
    final descChanged = _descriptionController.text.trim() != (widget.group.description ?? '');
    final privacyChanged = _isPrivate != widget.group.isPrivate;
    setState(() {
      _hasChanges = nameChanged || descChanged || privacyChanged;
    });
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _pickAndUploadCover() async {
    final l = AppLocalizations.of(context);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(l.takePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(l.chooseFromGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: Text(l.cancel),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingCover = true);

      final file = File(image.path);
      final extension = image.path.split('.').last.toLowerCase();
      final fileName = 'group_${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'group_covers/$fileName';

      await supabase.storage.from('groups').upload(filePath, file);
      final publicUrl = supabase.storage.from('groups').getPublicUrl(filePath);

      await _groupsService.updateGroup(
        groupId: widget.group.id,
        coverUrl: publicUrl,
      );

      setState(() {
        _currentCoverUrl = publicUrl;
        _isUploadingCover = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photoUpdated),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingCover = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newName = _nameController.text.trim();
      final newDescription = _descriptionController.text.trim();

      await _groupsService.updateGroup(
        groupId: widget.group.id,
        name: newName != widget.group.name ? newName : null,
        description: newDescription.isNotEmpty ? newDescription : null,
        clearDescription: newDescription.isEmpty && widget.group.description != null,
        isPrivate: _isPrivate != widget.group.isPrivate ? _isPrivate : null,
      );

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).changesSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _deleteGroup() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.deleteGroupTitle),
        content: Text(l.deleteGroupMessage),
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
    if (!mounted) return;

    // Double confirmation
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.confirmDeleteGroupTitle),
        content: Text(
          l.confirmDeleteGroupMessage(widget.group.name),
        ),
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

    if (doubleConfirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await _groupsService.deleteGroup(widget.group.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).groupDeleted),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersPage(
          groupId: widget.group.id,
          isAdmin: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = _isDark ? AppColors.bgDark : _kBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ConstrainedContent(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, AppSpace.m, AppSpace.l, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l.groupSettings,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.m),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image picker
                      _buildSectionTitle(l.groupPhoto),
                      const SizedBox(height: AppSpace.m),
                      GestureDetector(
                        onTap: _isUploadingCover ? null : _pickAndUploadCover,
                        child: Container(
                          height: 112,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _isDark ? AppColors.surfaceDark : _kCard,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Current image or placeholder
                              if (_currentCoverUrl != null)
                                CachedNetworkImage(
                                  imageUrl: _currentCoverUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 600,
                                  memCacheHeight: 336,
                                  errorWidget: (_, __, ___) => Container(
                                    color: _kSageGreen.withValues(alpha: 0.2),
                                    child: const Icon(Icons.image, color: _kSageGreen, size: 40),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _kSageGreen.withValues(alpha: 0.3),
                                        _kSageGreen.withValues(alpha: 0.1),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.image_outlined, color: _kSageGreen, size: 40),
                                ),

                              // Overlay
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                child: Center(
                                  child: _isUploadingCover
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.camera_alt_outlined,
                                                color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              l.changeImage,
                                              style: GoogleFonts.dmSans(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Name & description
                      _buildSectionTitle(l.information),
                      const SizedBox(height: AppSpace.m),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isDark ? AppColors.surfaceDark : _kCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: l.groupNameRequired,
                                filled: true,
                                fillColor: _isDark ? AppColors.bgDark : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.dmSans(fontSize: 15),
                              maxLength: 100,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l.nameRequired;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpace.m),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: l.description,
                                filled: true,
                                fillColor: _isDark ? AppColors.bgDark : Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.dmSans(fontSize: 15),
                              maxLines: 3,
                              maxLength: 500,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Privacy toggle
                      _buildSectionTitle(l.visibility),
                      const SizedBox(height: AppSpace.m),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isDark ? AppColors.surfaceDark : _kCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isPrivate ? Icons.lock_outline : Icons.public,
                              color: _isPrivate ? _kGold : _kSageGreen,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPrivate ? l.privateGroup : l.publicGroup,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isPrivate ? l.inviteOnly : l.visibleToAll,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isPrivate,
                              onChanged: (value) {
                                setState(() => _isPrivate = value);
                                _onFieldChanged();
                              },
                              activeThumbColor: _kGold,
                              activeTrackColor: _kGold.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Save button
                      if (_hasChanges) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kSageGreen, Color(0xFF5A8A7E)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      l.saveChanges,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                      ],

                      // Members section
                      _buildSectionTitle(l.members),
                      const SizedBox(height: AppSpace.m),
                      _buildSettingsTile(
                        icon: Icons.people_outline,
                        title: l.manageMembers,
                        subtitle: l.manageMembersSubtitle,
                        onTap: _navigateToMembers,
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Danger zone
                      _buildSectionTitle(l.dangerZone, color: AppColors.error),
                      const SizedBox(height: AppSpace.m),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _buildSettingsTile(
                          icon: Icons.delete_forever_outlined,
                          title: l.deleteButton,
                          subtitle: l.deleteChallengeMessage,
                          iconColor: AppColors.error,
                          titleColor: AppColors.error,
                          onTap: _isDeleting ? null : _deleteGroup,
                          useBg: false,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: color ?? _kSageGreen,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
    bool useBg = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: useBg
            ? BoxDecoration(
                color: _isDark ? AppColors.surfaceDark : _kCard,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? _kSageGreen, size: 22),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? (_isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
