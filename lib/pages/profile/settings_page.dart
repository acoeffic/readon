import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subscription_provider.dart';
import 'notification_settings_page.dart';
import 'kindle_login_page.dart';
import 'reading_goals_page.dart';
import 'upgrade_page.dart';
import '../../services/kindle_webview_service.dart';
import '../../services/kindle_auto_sync_service.dart';
import '../../models/feature_flags.dart';
import '../auth/auth_gate.dart';
import '../../services/trending_service.dart';
import '../../services/google_books_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isDeleting = false;
  String? _kindleLastSync;
  bool _kindleAutoSyncEnabled = true;
  bool _loadingAutoSync = true;
  bool _isProfilePrivate = false;
  bool _loadingPrivacy = true;

  @override
  void initState() {
    super.initState();
    _loadKindleSyncStatus();
    _loadKindleAutoSyncStatus();
    _loadPrivacySettings();
  }

  Future<void> _loadKindleSyncStatus() async {
    final lastSync = await KindleWebViewService().getLastSyncDate();
    if (mounted) setState(() => _kindleLastSync = lastSync);
  }

  Future<void> _loadKindleAutoSyncStatus() async {
    final service = KindleAutoSyncService();
    final enabled = await service.isAutoSyncEnabled();
    if (mounted) {
      setState(() {
        _kindleAutoSyncEnabled = enabled;
        _loadingAutoSync = false;
      });
    }
  }

  Future<void> _toggleKindleAutoSync(bool value) async {
    final service = KindleAutoSyncService();
    await service.setAutoSyncEnabled(value);
    if (mounted) setState(() => _kindleAutoSyncEnabled = value);
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('is_profile_private')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isProfilePrivate = profile?['is_profile_private'] as bool? ?? false;
          _loadingPrivacy = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadPrivacySettings: $e');
      if (mounted) {
        setState(() => _loadingPrivacy = false);
      }
    }
  }

  Future<void> _toggleProfilePrivacy(bool value) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'is_profile_private': value})
          .eq('id', user.id);

      setState(() => _isProfilePrivate = value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Profil privé activé. Seuls tes amis verront tes statistiques.'
                  : 'Profil public activé. Tout le monde peut voir tes statistiques.',
            ),
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

  String _formatSyncDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _openKindleLogin() async {
    final result = await Navigator.of(context).push<KindleReadingData>(
      MaterialPageRoute(builder: (context) => const KindleLoginPage()),
    );

    if (result != null && mounted) {
      await _loadKindleSyncStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kindle synchronisé avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

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
      final fileExtension = image.path.split('.').last.toLowerCase();
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
        debugPrint('Erreur suppression ancien avatar: $e');
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
      debugPrint('Erreur upload photo: $e');
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
      debugPrint('Erreur récupération nom: $e');
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

    if (newName == null || newName.trim().isEmpty) return;

    final cleaned = newName.trim().replaceAll(RegExp(r'<[^>]*>'), '');
    if (cleaned.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nom doit contenir au moins 2 caractères')),
        );
      }
      return;
    }
    if (cleaned.length > 50) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nom ne doit pas dépasser 50 caractères')),
        );
      }
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'display_name': cleaned})
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

  Future<void> _deleteAccount() async {
    // Dialog 1 : avertissement
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: const Text('Supprimer ton compte ?'),
        content: const Text(
          'Cette action est irréversible. Toutes tes données '
          '(livres, sessions de lecture, badges, amis, groupes) '
          'seront définitivement supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Continuer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;

    // Dialog 2 : taper "SUPPRIMER" pour confirmer
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              title: const Text('Confirmer la suppression'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pour confirmer, tape SUPPRIMER ci-dessous :'),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'SUPPRIMER',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: confirmController.text == 'SUPPRIMER'
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    'Supprimer définitivement',
                    style: TextStyle(
                      color: confirmController.text == 'SUPPRIMER'
                          ? AppColors.error
                          : Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    confirmController.dispose();
    if (confirmed != true || !mounted) return;

    // Appel RPC
    setState(() => _isDeleting = true);

    try {
      final result = await supabase.rpc('delete_user_account');
      final response = Map<String, dynamic>.from(result as Map);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Erreur inconnue');
      }

      // Vider les caches en mémoire avant déconnexion
      TrendingService.clearCache();
      GoogleBooksService.clearCache();

      // Déconnexion et redirection
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // L'utilisateur n'existe plus, signOut peut échouer
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isFrench = localeProvider.locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, 0),
              child: const BackHeader(
                title: 'Paramètres',
                titleColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

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

              // --- Section Abonnement ---
              Builder(builder: (context) {
                final sub = context.watch<SubscriptionProvider>();
                final String subLabel;
                if (sub.isPremium) {
                  final expStr = sub.expiresAt != null
                      ? '${sub.expiresAt!.day}/${sub.expiresAt!.month}/${sub.expiresAt!.year}'
                      : '';
                  subLabel = sub.isTrial
                      ? 'Essai gratuit${expStr.isNotEmpty ? ' (jusqu\'au $expStr)' : ''}'
                      : 'Premium actif${expStr.isNotEmpty ? ' (jusqu\'au $expStr)' : ''}';
                } else {
                  subLabel = 'Passer à Premium';
                }
                return _SettingsSection(
                  title: 'Abonnement',
                  items: [
                    _SettingsItem(
                      label: sub.isPremium ? subLabel : 'Passer à Premium',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UpgradePage()),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: AppSpace.m),

              // --- Section Confidentialité ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confidentialité',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: AppSpace.s),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔒 Profil privé',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isProfilePrivate
                                        ? 'Tes statistiques sont cachées'
                                        : 'Tes statistiques sont publiques',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_loadingPrivacy)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Switch(
                                value: _isProfilePrivate,
                                onChanged: _toggleProfilePrivacy,
                                activeTrackColor: AppColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.m),
                        Container(
                          padding: const EdgeInsets.all(AppSpace.m),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.accentDark.withValues(alpha: 0.3)
                                : AppColors.accentLight.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                              const SizedBox(width: AppSpace.s),
                              Expanded(
                                child: Text(
                                  _isProfilePrivate
                                      ? 'Les autres utilisateurs ne verront que ton nom et ta photo de profil.'
                                      : 'Les autres utilisateurs pourront voir tes badges, livres, flow et statistiques.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Lecture ---
              _SettingsSection(
                title: 'Lecture',
                items: [
                  _SettingsItem(
                    label: '🎯 Modifier l\'objectif de lecture',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ReadingGoalsPage(),
                        ),
                      );
                    },
                  ),
                  _SettingsItem(
                    label: '🔔 Notifications de flow',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NotificationSettingsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Kindle ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kindle',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: AppSpace.s),
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
                        _SettingsItem(
                          label: _kindleLastSync != null
                              ? '📚 Resynchroniser Kindle'
                              : '📚 Connecter Kindle',
                          onTap: _openKindleLogin,
                        ),
                        if (_kindleLastSync != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.s),
                            child: _SettingsItem(
                              label: '✅ Dernière sync: ${_formatSyncDate(_kindleLastSync!)}',
                            ),
                          ),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpace.m),
                          Builder(builder: (context) {
                            final sub = context.watch<SubscriptionProvider>();
                            final isPremium = sub.isPremium;
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Sync automatique',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          if (!isPremium) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const UpgradePage()),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Premium',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Synchronise tes livres Kindle à chaque ouverture',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_loadingAutoSync)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Switch(
                                    value: isPremium && _kindleAutoSyncEnabled,
                                    onChanged: isPremium ? _toggleKindleAutoSync : null,
                                    activeTrackColor: AppColors.primary,
                                  ),
                              ],
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Apparence ---
              _SettingsSection(
                title: 'Apparence',
                items: [
                  _SettingsItem(
                    label: isDark ? '🌞 Thème clair' : '🌞 Thème clair (actif)',
                    onTap: isDark
                        ? () => themeProvider.setThemeMode(ThemeMode.light)
                        : null,
                  ),
                  _SettingsItem(
                    label: isDark ? '🌙 Thème sombre (actif)' : '🌙 Thème sombre',
                    onTap: !isDark
                        ? () => themeProvider.setThemeMode(ThemeMode.dark)
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Langue ---
              _SettingsSection(
                title: 'Langue',
                items: [
                  _SettingsItem(
                    label: isFrench ? '🇫🇷 Français (actif)' : '🇫🇷 Français',
                    onTap: !isFrench
                        ? () => localeProvider.setLocale(const Locale('fr'))
                        : null,
                  ),
                  _SettingsItem(
                    label: isFrench ? '🇬🇧 English' : '🇬🇧 English (active)',
                    onTap: isFrench
                        ? () => localeProvider.setLocale(const Locale('en'))
                        : null,
                  ),
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
                  color: Theme.of(context).cardColor,
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
                      TrendingService.clearCache();
                      GoogleBooksService.clearCache();
                      await Supabase.instance.client.auth.signOut();

                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
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

              const SizedBox(height: AppSpace.m),

              // --- Zone de danger : Suppression du compte ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zone de danger',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      'La suppression du compte est irréversible.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: AppSpace.m),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isDeleting ? null : _deleteAccount,
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                              )
                            : const Text(
                                'Supprimer mon compte',
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
                  ],
                ),
              ),
            ),
          ],
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
            color: Theme.of(context).cardColor,
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
                  color: onTap == null ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4) : null,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
