import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';
import 'group_members_page.dart';

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

  Future<void> _pickAndUploadCover() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Annuler'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingCover = true);

      final file = File(image.path);
      final extension = image.path.split('.').last.toLowerCase();
      final fileName = 'group_${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'group_covers/$fileName';

      await supabase.storage.from('profiles').upload(filePath, file);
      final publicUrl = supabase.storage.from('profiles').getPublicUrl(filePath);

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
          const SnackBar(
            content: Text('Photo mise à jour'),
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
          const SnackBar(
            content: Text('Modifications enregistrées'),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Supprimer le groupe ?'),
        content: const Text(
          'Cette action est irréversible. Tous les membres seront retirés et les données du groupe seront perdues.',
        ),
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

    // Double confirmation
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer "${widget.group.name}" définitivement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer définitivement',
              style: TextStyle(color: AppColors.error),
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
          const SnackBar(
            content: Text('Groupe supprimé'),
            backgroundColor: Colors.orange,
          ),
        );
        // Pop back to group list (pop settings + pop detail)
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: const BackHeader(title: 'Réglages du groupe'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover photo section
                      _buildSectionTitle('Photo du groupe'),
                      const SizedBox(height: AppSpace.m),
                      Center(
                        child: GestureDetector(
                          onTap: _isUploadingCover ? null : _pickAndUploadCover,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.l),
                                  image: _currentCoverUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_currentCoverUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _currentCoverUrl == null
                                    ? const Icon(
                                        Icons.group,
                                        color: AppColors.primary,
                                        size: 48,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: _isUploadingCover
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Group info section
                      _buildSectionTitle('Informations'),
                      const SizedBox(height: AppSpace.m),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du groupe *',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 100,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpace.m),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        maxLength: 500,
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Visibility section
                      _buildSectionTitle('Visibilité'),
                      const SizedBox(height: AppSpace.m),
                      Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(
                            color: _isPrivate
                                ? Colors.orange.withOpacity(0.5)
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
                                    _isPrivate ? 'Groupe privé' : 'Groupe public',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isPrivate
                                        ? 'Uniquement accessible sur invitation'
                                        : 'Visible par tous les utilisateurs',
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
                              onChanged: (value) {
                                setState(() => _isPrivate = value);
                                _onFieldChanged();
                              },
                              activeColor: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Save button
                      if (_hasChanges)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.m),
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
                                : const Text(
                                    'Enregistrer les modifications',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      if (_hasChanges) const SizedBox(height: AppSpace.xl),

                      // Members section
                      _buildSectionTitle('Membres'),
                      const SizedBox(height: AppSpace.m),
                      _buildSettingsTile(
                        icon: Icons.people,
                        title: 'Gérer les membres',
                        subtitle: 'Voir, inviter et gérer les rôles',
                        onTap: _navigateToMembers,
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // Danger zone
                      _buildSectionTitle('Zone de danger', color: AppColors.error),
                      const SizedBox(height: AppSpace.m),
                      _buildSettingsTile(
                        icon: Icons.delete_forever,
                        title: 'Supprimer le groupe',
                        subtitle: 'Action irréversible',
                        iconColor: AppColors.error,
                        titleColor: AppColors.error,
                        onTap: _isDeleting ? null : _deleteGroup,
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
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.grey.shade500,
        letterSpacing: 0.5,
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.primary),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
