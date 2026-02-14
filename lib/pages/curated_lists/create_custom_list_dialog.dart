import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/icon_options.dart';
import '../../models/user_custom_list.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';

/// Affiche un bottom sheet pour créer ou modifier une liste personnalisée.
/// Retourne la [UserCustomList] créée/modifiée, ou null si annulé.
Future<UserCustomList?> showCreateCustomListSheet(
  BuildContext context, {
  UserCustomList? existingList,
}) {
  return showModalBottomSheet<UserCustomList>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CreateCustomListSheet(existingList: existingList),
  );
}

class _CreateCustomListSheet extends StatefulWidget {
  final UserCustomList? existingList;

  const _CreateCustomListSheet({this.existingList});

  @override
  State<_CreateCustomListSheet> createState() => _CreateCustomListSheetState();
}

class _CreateCustomListSheetState extends State<_CreateCustomListSheet> {
  final _service = UserCustomListsService();
  final _titleController = TextEditingController();
  String _selectedIcon = 'book-open';
  String _selectedColor = kListColorOptions.first;
  bool _isPublic = false;
  bool _isSaving = false;

  bool get _isEditing => widget.existingList != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingList != null) {
      _titleController.text = widget.existingList!.title;
      _selectedIcon = widget.existingList!.iconName;
      _selectedColor = widget.existingList!.gradientColor;
      _isPublic = widget.existingList!.isPublic;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      UserCustomList result;

      if (_isEditing) {
        await _service.updateList(
          widget.existingList!.id,
          title: title,
          iconName: _selectedIcon,
          gradientColor: _selectedColor,
          isPublic: _isPublic,
        );
        result = widget.existingList!.copyWith(
          title: title,
          iconName: _selectedIcon,
          gradientColor: _selectedColor,
          isPublic: _isPublic,
        );
      } else {
        result = await _service.createList(
          title: title,
          iconName: _selectedIcon,
          gradientColor: _selectedColor,
          isPublic: _isPublic,
        );
      }

      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final gradientColors = generateGradientFromHex(_selectedColor);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poignée
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.l),

                // Titre du dialog
                Text(
                  _isEditing ? 'Modifier la liste' : 'Nouvelle liste',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpace.l),

                // Aperçu
                _buildPreview(gradientColors),
                const SizedBox(height: AppSpace.l),

                // Champ titre
                TextField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nom de la liste',
                    hintText: 'Ex : Livres à lire cet été',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    prefixIcon: Icon(
                      mapLucideIconName(_selectedIcon),
                      color: hexToColor(_selectedColor),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpace.l),

                // Sélection icône
                Text(
                  'Icône',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpace.s),
                _buildIconPicker(),
                const SizedBox(height: AppSpace.l),

                // Sélection couleur
                Text(
                  'Couleur',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpace.s),
                _buildColorPicker(),
                const SizedBox(height: AppSpace.l),

                // Visibilité publique / privée
                _buildVisibilityToggle(),
                const SizedBox(height: AppSpace.xl),

                // Bouton créer/modifier
                FilledButton(
                  onPressed: _titleController.text.trim().isEmpty || _isSaving
                      ? null
                      : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Enregistrer' : 'Créer la liste',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(List<Color> gradientColors) {
    final title = _titleController.text.trim();
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            mapLucideIconName(_selectedIcon),
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title.isEmpty ? 'Ma liste' : title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kIconOptions.entries.map((entry) {
        final isSelected = _selectedIcon == entry.key;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = entry.key),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? hexToColor(_selectedColor).withValues(alpha: 0.15)
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(
                color: isSelected
                    ? hexToColor(_selectedColor)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              entry.value,
              size: 20,
              color: isSelected
                  ? hexToColor(_selectedColor)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: kListColorOptions.map((hex) {
        final isSelected = _selectedColor == hex;
        final color = hexToColor(hex);
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          _isPublic ? LucideIcons.globe : LucideIcons.lock,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        title: Text(
          _isPublic ? 'Liste publique' : 'Liste privée',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _isPublic
              ? 'Visible par tes amis sur ton profil'
              : 'Visible uniquement par toi',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
          ),
        ),
        trailing: Switch.adaptive(
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
          activeColor: const Color(0xFFFF6B35),
        ),
      ),
    );
  }
}
