import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _changeProfilePicture() async {
    try {
      // Afficher le choix caméra/galerie
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

      // Sélectionner l'image
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // VALIDATION: Vérifier la taille du fichier (max 5MB)
      final fileSize = await File(image.path).length();
      const maxSize = 5 * 1024 * 1024; // 5MB en bytes
      
      if (fileSize > maxSize) {
        throw Exception('Image trop grande. Taille maximum: 5MB');
      }

      // VALIDATION: Vérifier que c'est bien une image
      final fileExtension = image.path.split('.').last.toLowerCase();;
final allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

if (!allowedExtensions.contains(fileExtension)) {
  throw Exception('Format non supporté. Utilisez JPG, PNG ou WebP');
}

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Non connecté');
      }

      // Nom du fichier unique avec extension appropriée
      final extension = image.path.split('.').last.toLowerCase();
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = 'avatars/${user.id}/$fileName';

      // Supprimer l'ancien avatar si existant
      try {
        final profile = await supabase
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        
        final oldAvatarUrl = profile?['avatar_url'] as String?;
        if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
          // Extraire le path du fichier depuis l'URL
          final uri = Uri.parse(oldAvatarUrl);
          final oldPath = uri.pathSegments.skip(4).join('/'); // Skip /storage/v1/object/public/profiles/
          
          if (oldPath.isNotEmpty) {
            await supabase.storage
                .from('profiles')
                .remove([oldPath]);
          }
        }
      } catch (e) {
        print('Erreur suppression ancien avatar: $e');
        // Continue quand même avec l'upload
      }

      // Upload vers Supabase Storage
      await supabase.storage
          .from('profiles')
          .upload(
            filePath, 
            File(image.path),
            fileOptions: const FileOptions(
              upsert: false, // Ne pas écraser, créer nouveau fichier
            ),
          );

      // Récupérer l'URL publique
      final avatarUrl = supabase.storage
          .from('profiles')
          .getPublicUrl(filePath);

      // Mettre à jour le profil dans la base de données
      await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo de profil mise à jour!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erreur upload photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _changeDisplayName() async {
    final controller = TextEditingController();
    
    // Récupérer le nom actuel
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();

      controller.text = profile?['display_name'] ?? '';
    } catch (e) {
      print('Erreur récupération nom: $e');
    }

    if (!mounted) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Modifier le nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom d\'affichage',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'display_name': newName})
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nom mis à jour!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Paramètres'),
              const SizedBox(height: AppSpace.l),

              // --- Section Profil ---
              _SettingsSection(
                title: 'Profil',
                items: [
                  _SettingsItem(
                    label: '✏️ Modifier le nom',
                    onTap: _changeDisplayName,
                  ),
                  _SettingsItem(
                    label: _isUploading 
                        ? '📸 Upload en cours...' 
                        : '📸 Changer la photo de profil',
                    onTap: _isUploading ? null : _changeProfilePicture,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Lecture ---
              _SettingsSection(
                title: 'Lecture',
                items: const [
                  _SettingsItem(label: '🎯 Modifier l\'objectif de lecture'),
                  _SettingsItem(label: '🔔 Notifications de progression'),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Apparence ---
              _SettingsSection(
                title: 'Apparence',
                items: const [
                  _SettingsItem(label: '🌞 Thème clair (actif)'),
                  _SettingsItem(label: '🌙 Thème sombre'),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Compte ---
              _SettingsSection(
                title: 'Compte',
                items: const [
                  _SettingsItem(label: '🖥️ Gérer connexions & appareils'),
                ],
              ),

              const SizedBox(height: AppSpace.l),

              // --- Déconnexion ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        title: const Text('Se déconnecter ?'),
                        content: const Text('Tu vas être déconnecté. Continuer ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await Supabase.instance.client.auth.signOut();
                      
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/welcome',
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: const Text(
                    '❌ Se déconnecter',
                    style: TextStyle(
                      color: AppColors.error,
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
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpace.s),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(bottom: e == items.last ? 0 : AppSpace.s),
                    child: e,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SettingsItem({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: onTap == null ? Colors.grey : null,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}