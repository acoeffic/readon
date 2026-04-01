import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/back_header.dart';
import '../../providers/theme_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/subscription_provider.dart';
import '../../services/subscription_service.dart';
import 'notification_settings_page.dart';
import 'kindle_login_page.dart';
import 'reading_goals_page.dart';
import 'upgrade_page.dart';
import '../../services/kindle_webview_service.dart';
import '../../services/kindle_auto_sync_service.dart';
import '../../models/feature_flags.dart';
import '../auth/auth_gate.dart';
import '../auth/terms_of_service_page.dart';
import '../auth/legal_notice_page.dart';
import '../auth/privacy_policy_page.dart';
import '../../services/trending_service.dart';
import '../../services/google_books_service.dart';
import '../../services/notion_service.dart';
import '../../services/avatar_cache_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/books_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _hideReadingHours = false;
  bool _loadingPrivacy = true;
  bool _notionConnected = false;
  String? _notionWorkspaceName;
  bool _loadingNotion = true;
  bool _refreshingCovers = false;

  @override
  void initState() {
    super.initState();
    _loadKindleSyncStatus();
    _loadKindleAutoSyncStatus();
    _loadPrivacySettings();
    _loadNotionStatus();
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
          .select('is_profile_private, hide_reading_hours')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isProfilePrivate = profile?['is_profile_private'] as bool? ?? false;
          _hideReadingHours = profile?['hide_reading_hours'] as bool? ?? false;
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
                  ? AppLocalizations.of(context).profilePrivateEnabled
                  : AppLocalizations.of(context).profilePublicEnabled,
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

  Future<void> _toggleHideReadingHours(bool value) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('profiles')
          .update({'hide_reading_hours': value})
          .eq('id', user.id);

      setState(() => _hideReadingHours = value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? AppLocalizations.of(context).readingHoursHiddenSnack
                  : AppLocalizations.of(context).readingHoursVisibleSnack,
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
      if (diff.inMinutes < 60) return AppLocalizations.of(context).timeAgoMinutes(diff.inMinutes);
      if (diff.inHours < 24) return AppLocalizations.of(context).timeAgoHours(diff.inHours);
      if (diff.inDays < 7) return AppLocalizations.of(context).timeAgoDays(diff.inDays);
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
        SnackBar(
          content: Text(AppLocalizations.of(context).kindleSyncedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadNotionStatus() async {
    final notion = NotionService();
    await notion.refreshConnectionStatus();
    final connected = await notion.isConnected();
    final name = await notion.getWorkspaceName();
    if (mounted) {
      setState(() {
        _notionConnected = connected;
        _notionWorkspaceName = name;
        _loadingNotion = false;
      });
    }
  }

  Future<void> _connectNotion() async {
    final sub = context.read<SubscriptionProvider>();
    if (!sub.isPremium) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UpgradePage()),
      );
      return;
    }

    final notion = NotionService();
    notion.onOAuthCallback = (code) async {
      try {
        final workspaceName = await notion.exchangeCode(code);
        if (mounted) {
          setState(() {
            _notionConnected = true;
            _notionWorkspaceName = workspaceName;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connecté à $workspaceName'),
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
    };

    final url = Uri.parse(notion.getOAuthUrl());
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _disconnectNotion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(AppLocalizations.of(context).disconnectNotionTitle),
        content: Text(AppLocalizations.of(context).disconnectNotionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppLocalizations.of(context).disconnect,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await NotionService().disconnect();
      if (mounted) {
        setState(() {
          _notionConnected = false;
          _notionWorkspaceName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).notionDisconnected),
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

  Future<void> _refreshCovers() async {
    if (_refreshingCovers) return;
    setState(() => _refreshingCovers = true);
    try {
      final count = await BooksService().refreshAllCovers();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0 ? l10n.coversRefreshed(count) : l10n.coversUpToDate),
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
    } finally {
      if (mounted) setState(() => _refreshingCovers = false);
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
                title: Text(AppLocalizations.of(context).takePhoto),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(AppLocalizations.of(context).chooseFromGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: Text(AppLocalizations.of(context).cancel),
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
        throw Exception(AppLocalizations.of(context).imageTooLarge);
      }

      // VALIDATION: Vérifier que c'est bien une image
      final fileExtension = image.path.split('.').last.toLowerCase();
final allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

if (!allowedExtensions.contains(fileExtension)) {
  throw Exception(AppLocalizations.of(context).unsupportedFormat);
}

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception(AppLocalizations.of(context).notConnected);
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
          final oldPath = uri.pathSegments.skip(5).join('/'); // Skip /storage/v1/object/public/profiles/
          
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
      final updateResult = await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', supabase.auth.currentUser!.id)
          .select()
          .single();

      debugPrint('Avatar URL saved: ${updateResult['avatar_url']}');

      // Sauvegarder en cache local
      await AvatarCacheService.instance.saveFromFile(File(image.path), avatarUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profilePictureUpdated),
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
        title: Text(AppLocalizations.of(context).editNameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).displayName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;

    final cleaned = newName.trim().replaceAll(RegExp(r'<[^>]*>'), '');
    if (cleaned.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).nameMinLength)),
        );
      }
      return;
    }
    if (cleaned.length > 50) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).nameMaxLength)),
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
          SnackBar(
            content: Text(AppLocalizations.of(context).nameUpdated),
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
        title: Text(AppLocalizations.of(context).deleteAccountTitle),
        content: Text(AppLocalizations.of(context).deleteAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppLocalizations.of(context).continueButton,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;

    // Dialog 2 : taper "SUPPRIMER" pour confirmer
    final confirmController = TextEditingController();
    final deleteKeyword = AppLocalizations.of(context).deleteKeyword;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
              title: Text(AppLocalizations.of(context).confirmDeletion),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context).typeDeleteToConfirm),
                  const SizedBox(height: AppSpace.m),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: deleteKeyword,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
                TextButton(
                  onPressed: confirmController.text == deleteKeyword
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    AppLocalizations.of(context).deleteForever,
                    style: TextStyle(
                      color: confirmController.text == deleteKeyword
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

    if (confirmed != true || !mounted) return;

    // Capturer la référence au provider avant les appels async
    final subscriptionProvider = context.read<SubscriptionProvider>();

    // Appel RPC
    setState(() => _isDeleting = true);

    try {
      // Supprimer les fichiers storage via l'API avant le RPC
      final userId = supabase.auth.currentUser!.id;
      try {
        final avatars = await supabase.storage
            .from('profiles')
            .list(path: 'avatars/$userId');
        if (avatars.isNotEmpty) {
          await supabase.storage.from('profiles').remove(
                avatars.map((f) => 'avatars/$userId/${f.name}').toList(),
              );
        }
      } catch (_) {}
      try {
        final annotations = await supabase.storage
            .from('annotations')
            .list(path: userId);
        if (annotations.isNotEmpty) {
          await supabase.storage.from('annotations').remove(
                annotations.map((f) => '$userId/${f.name}').toList(),
              );
        }
      } catch (_) {}

      final result = await supabase.rpc('delete_user_account');
      final response = Map<String, dynamic>.from(result as Map);

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Erreur inconnue');
      }

      // Nettoyage caches et listeners
      TrendingService.clearCache();
      GoogleBooksService.clearCache();
      await AvatarCacheService.instance.clear();
      subscriptionProvider.detachRevenueCatListener();

      // Nettoyer le token FCM AVANT la déconnexion
      await PushNotificationService().clearToken();

      // Déconnexion Supabase AVANT la navigation pour que
      // AuthGate voit session == null et affiche LoginPage
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      // Naviguer vers AuthGate
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }

      // Cleanup fire-and-forget APRÈS la navigation
      // (les anciens widgets sont déjà démontés)
      Supabase.instance.client.removeAllChannels();
      SubscriptionService().logoutUser();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorDeletingAccount(e.toString())),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, 0),
              child: BackHeader(
                title: l10n.settings,
                titleColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: ConstrainedContent(
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // --- Section Profil ---
              _SettingsSection(
                title: l10n.profileSection,
                items: [
                  _SettingsItem(
                    label: l10n.editName,
                    onTap: _changeDisplayName,
                  ),
                  _SettingsItem(
                    label: _isUploading
                        ? l10n.uploadingPhoto
                        : l10n.changeProfilePicture,
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
                      ? (expStr.isNotEmpty ? l10n.freeTrialUntil(expStr) : l10n.freeTrial)
                      : (expStr.isNotEmpty ? l10n.premiumActiveUntil(expStr) : l10n.premiumActive);
                } else {
                  subLabel = l10n.upgradeToPremium;
                }
                return _SettingsSection(
                  title: l10n.subscriptionSection,
                  items: [
                    _SettingsItem(
                      label: sub.isPremium ? subLabel : l10n.upgradeToPremium,
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
                    l10n.privacySection,
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
                                    l10n.privateProfile,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isProfilePrivate
                                        ? l10n.statsHidden
                                        : l10n.statsPublic,
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
                                      ? l10n.privateProfileInfoOn
                                      : l10n.privateProfileInfoOff,
                                  style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.m),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.hideReadingHours,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _hideReadingHours
                                        ? l10n.readingHoursHidden
                                        : l10n.readingHoursVisible,
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
                                value: _hideReadingHours,
                                onChanged: _toggleHideReadingHours,
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
                                  l10n.readingHoursInfo,
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
                title: l10n.readingSection,
                items: [
                  _SettingsItem(
                    label: l10n.editReadingGoal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ReadingGoalsPage(),
                        ),
                      );
                    },
                  ),
                  _SettingsItem(
                    label: l10n.notificationCenter,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const NotificationSettingsPage(),
                        ),
                      );
                    },
                  ),
                  _SettingsItem(
                    label: _refreshingCovers
                        ? l10n.refreshingCovers
                        : l10n.refreshCovers,
                    onTap: _refreshingCovers ? null : _refreshCovers,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Kindle ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.kindleSection,
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
                              ? l10n.resyncKindle
                              : l10n.connectKindle,
                          onTap: _openKindleLogin,
                        ),
                        if (_kindleLastSync != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.s),
                            child: _SettingsItem(
                              label: l10n.lastSync(_formatSyncDate(_kindleLastSync!)),
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
                                            l10n.autoSync,
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
                                        l10n.kindleAutoSyncDescription,
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

              // --- Section Notion ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notionSection,
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
                    child: _loadingNotion
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _notionConnected
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.connectedTo(_notionWorkspaceName ?? "Notion"),
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.notionSheetsDescription,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpace.m),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _connectNotion,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          child: Text(l10n.reconnect),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _disconnectNotion,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(l10n.disconnect),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SettingsItem(
                                    label: l10n.connectNotion,
                                    onTap: _connectNotion,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.notionSyncDescription,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      Builder(builder: (context) {
                                        final isPremium = context.watch<SubscriptionProvider>().isPremium;
                                        if (isPremium) return const SizedBox.shrink();
                                        return GestureDetector(
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
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Apparence ---
              _SettingsSection(
                title: l10n.appearanceSection,
                items: [
                  _SettingsItem(
                    label: themeProvider.themeMode == ThemeMode.light
                        ? l10n.lightThemeActive
                        : l10n.lightTheme,
                    onTap: themeProvider.themeMode != ThemeMode.light
                        ? () => themeProvider.setThemeMode(ThemeMode.light)
                        : null,
                  ),
                  _SettingsItem(
                    label: themeProvider.themeMode == ThemeMode.dark
                        ? l10n.darkThemeActive
                        : l10n.darkTheme,
                    onTap: themeProvider.themeMode != ThemeMode.dark
                        ? () => themeProvider.setThemeMode(ThemeMode.dark)
                        : null,
                  ),
                  _SettingsItem(
                    label: themeProvider.themeMode == ThemeMode.system
                        ? l10n.systemThemeActive
                        : l10n.systemTheme,
                    onTap: themeProvider.themeMode != ThemeMode.system
                        ? () => themeProvider.setThemeMode(ThemeMode.system)
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Compte ---
              _SettingsSection(
                title: l10n.accountSection,
                items: [
                  _SettingsItem(label: l10n.manageConnections),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Légal ---
              _SettingsSection(
                title: l10n.legalSection,
                items: [
                  _SettingsItem(
                    label: l10n.termsOfService,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                    ),
                  ),
                  _SettingsItem(
                    label: l10n.privacyPolicy,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                    ),
                  ),
                  _SettingsItem(
                    label: l10n.legalNoticesItem,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LegalNoticePage()),
                    ),
                  ),
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
                        title: Text(l10n.logoutTitle),
                        content: Text(l10n.logoutMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text(
                              l10n.confirm,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      TrendingService.clearCache();
                      GoogleBooksService.clearCache();
                      await AvatarCacheService.instance.clear();
                      await PushNotificationService().clearToken();
                      await SubscriptionService().logoutUser();
                      await Supabase.instance.client.auth.signOut();

                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: Text(
                    l10n.logout,
                    style: const TextStyle(
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
                      l10n.dangerZone,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      l10n.deleteAccountWarning,
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
                            : Text(
                                l10n.deleteMyAccount,
                                style: const TextStyle(
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
