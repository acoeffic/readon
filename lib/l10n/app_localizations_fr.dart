// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navFeed => 'Feed';

  @override
  String get navLibrary => 'Biblio';

  @override
  String get navClub => 'Club';

  @override
  String get navProfile => 'Mon espace';

  @override
  String get kindleSyncedAutomatically => 'Kindle synchronisé automatiquement';

  @override
  String get enterEmailToReset => 'Entre ton email pour réinitialiser';

  @override
  String get emailSentCheckInbox => 'Email envoyé, vérifie ta boîte.';

  @override
  String get errorSendingEmail => 'Erreur lors de l\'envoi de l\'email';

  @override
  String tooManyAttemptsRetryIn(int seconds) {
    return 'Trop de tentatives. Réessaie dans ${seconds}s';
  }

  @override
  String get emailAndPasswordRequired => 'Email et mot de passe requis';

  @override
  String get loginFailed => 'Connexion impossible';

  @override
  String get unknownError => 'Erreur inconnue';

  @override
  String get errorSignInApple => 'Erreur lors de la connexion avec Apple';

  @override
  String get errorSignInGoogle => 'Erreur lors de la connexion avec Google';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get reader => 'reader.';

  @override
  String get email => 'EMAIL';

  @override
  String get emailLower => 'Email';

  @override
  String get password => 'PASSWORD';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get or => 'or';

  @override
  String get newToLexDay => 'New to LexDay? ';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get emailAlreadyUsed => 'Email déjà utilisé';

  @override
  String get emailAlreadyUsedMessage =>
      'Cette adresse email est déjà associée à un compte existant. Souhaitez-vous réinitialiser votre mot de passe ?';

  @override
  String get back => 'Retour';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetEmailSent =>
      'Email de réinitialisation envoyé. Vérifie ta boîte mail.';

  @override
  String get passwordMin8Chars =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get passwordRequirements =>
      'Le mot de passe doit contenir majuscule, minuscule et chiffre';

  @override
  String get mustAcceptTerms =>
      'Vous devez accepter les conditions d\'utilisation';

  @override
  String get accountCreatedCheckEmail => 'Compte créé, vérifie tes emails.';

  @override
  String get createAccountTitle => 'Créer un compte';

  @override
  String get joinLexDay => 'Rejoins LexDay';

  @override
  String get enterInfoToStart => 'Entre tes informations pour commencer à lire';

  @override
  String get name => 'Nom';

  @override
  String get yourName => 'Ton nom';

  @override
  String get yourEmail => 'ton.email@mail.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get alreadyHaveAccount => 'Déjà un compte ? Se connecter';

  @override
  String get legalNotices => 'Mentions légales';

  @override
  String get emailSent => 'Email envoyé';

  @override
  String get checkYourEmail => 'Vérifie ta boîte mail';

  @override
  String get confirmEmailSent =>
      'Nous t\'avons envoyé un lien pour confirmer ton adresse email.';

  @override
  String get iConfirmedMyEmail => 'J\'ai confirmé mon email';

  @override
  String get suggestionsForYou => 'Suggestions pour toi';

  @override
  String bookAddedToLibrary(String title) {
    return '$title ajouté à votre bibliothèque';
  }

  @override
  String get errorAddingBook => 'Erreur lors de l\'ajout du livre';

  @override
  String get recentSessions => 'Sessions récentes';

  @override
  String get recentBadges => 'Badges récents';

  @override
  String get friendsActivity => 'Activité de tes amis';

  @override
  String get refresh => 'Rafraîchir';

  @override
  String get friendsNotReadToday =>
      'Tes amis n\'ont pas encore lu aujourd\'hui';

  @override
  String get noActivityYet => 'Pas encore d\'activité';

  @override
  String get addFriendsToSeeActivity =>
      'Ajoutez des amis pour voir leurs lectures!';

  @override
  String get shareInviteText =>
      '📖 Rejoins-moi sur LexDay !\n\nTu lis quoi en ce moment ? 👀\nlexday.app';

  @override
  String errorGeneric(String message) {
    return 'Erreur: $message';
  }

  @override
  String get myLibrary => 'Ma Bibliothèque';

  @override
  String get refreshTooltip => 'Rafraîchir';

  @override
  String get searchBook => 'Rechercher un livre...';

  @override
  String get statusLabel => 'Statut';

  @override
  String get genreLabel => 'Genre';

  @override
  String get noBooksInLibrary => 'Aucun livre dans votre bibliothèque';

  @override
  String get scanOrSyncBooks =>
      'Scannez une couverture ou synchronisez vos livres Kindle';

  @override
  String authorFoundForBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Auteur trouvé pour $count livre$_temp0';
  }

  @override
  String get noAuthorFound => 'Aucun auteur trouvé';

  @override
  String get errorSearchingAuthors => 'Erreur lors de la recherche des auteurs';

  @override
  String get searchingInProgress => 'Recherche en cours...';

  @override
  String get searchMissingAuthors => 'Rechercher les auteurs manquants';

  @override
  String get settings => 'Paramètres';

  @override
  String get profileSection => 'Profil';

  @override
  String get editName => '✏️ Modifier le nom';

  @override
  String get uploadingPhoto => '📸 Upload en cours...';

  @override
  String get changeProfilePicture => '📸 Changer la photo de profil';

  @override
  String get subscriptionSection => 'Abonnement';

  @override
  String get upgradeToPremium => 'Passer à Premium';

  @override
  String get freeTrial => 'Essai gratuit';

  @override
  String freeTrialUntil(String date) {
    return 'Essai gratuit (jusqu\'au $date)';
  }

  @override
  String get premiumActive => 'Premium actif';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium actif (jusqu\'au $date)';
  }

  @override
  String get privacySection => 'Confidentialité';

  @override
  String get privateProfile => '🔒 Profil privé';

  @override
  String get statsHidden => 'Tes statistiques sont cachées';

  @override
  String get statsPublic => 'Tes statistiques sont publiques';

  @override
  String get privateProfileInfoOn =>
      'Les autres utilisateurs ne verront que ton nom et ta photo de profil.';

  @override
  String get privateProfileInfoOff =>
      'Les autres utilisateurs pourront voir tes badges, livres, flow et statistiques.';

  @override
  String get hideReadingHours => '⏱️ Masquer les heures de lecture';

  @override
  String get readingHoursHidden => 'Tes heures de lecture sont cachées';

  @override
  String get readingHoursVisible => 'Tes heures de lecture sont visibles';

  @override
  String get readingHoursInfo =>
      'Les autres utilisateurs ne verront pas ton temps de lecture total.';

  @override
  String get profilePrivateEnabled =>
      'Profil privé activé. Seuls tes amis verront tes statistiques.';

  @override
  String get profilePublicEnabled =>
      'Profil public activé. Tout le monde peut voir tes statistiques.';

  @override
  String get readingHoursHiddenSnack => 'Heures de lecture masquées.';

  @override
  String get readingHoursVisibleSnack => 'Heures de lecture visibles.';

  @override
  String get readingSection => 'Lecture';

  @override
  String get editReadingGoal => '🎯 Modifier l\'objectif de lecture';

  @override
  String get flowNotifications => '🔔 Notifications de flow';

  @override
  String get kindleSection => 'Kindle';

  @override
  String get resyncKindle => '📚 Resynchroniser Kindle';

  @override
  String get connectKindle => '📚 Connecter Kindle';

  @override
  String lastSync(String date) {
    return '✅ Dernière sync: $date';
  }

  @override
  String get autoSync => 'Sync automatique';

  @override
  String get kindleAutoSyncDescription =>
      'Synchronise tes livres Kindle à chaque ouverture';

  @override
  String get kindleSyncedSuccess => 'Kindle synchronisé avec succès !';

  @override
  String get notionSection => 'Notion';

  @override
  String connectedTo(String name) {
    return 'Connecté à $name';
  }

  @override
  String get notionSheetsDescription =>
      'Tes fiches de lecture peuvent être envoyées vers Notion';

  @override
  String get reconnect => 'Reconnecter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get connectNotion => '📝 Connecter Notion';

  @override
  String get notionSyncDescription =>
      'Synchronise tes fiches de lecture IA vers une base Notion';

  @override
  String get disconnectNotionTitle => 'Déconnecter Notion ?';

  @override
  String get disconnectNotionMessage =>
      'Tes fiches déjà synchronisées resteront dans Notion.';

  @override
  String get notionDisconnected => 'Notion déconnecté';

  @override
  String get appearanceSection => 'Apparence';

  @override
  String get lightTheme => '🌞 Thème clair';

  @override
  String get lightThemeActive => '🌞 Thème clair (actif)';

  @override
  String get darkTheme => '🌙 Thème sombre';

  @override
  String get darkThemeActive => '🌙 Thème sombre (actif)';

  @override
  String get languageSection => 'Langue';

  @override
  String get frenchActive => '🇫🇷 Français (actif)';

  @override
  String get french => '🇫🇷 Français';

  @override
  String get english => '🇬🇧 English';

  @override
  String get englishActive => '🇬🇧 English (active)';

  @override
  String get accountSection => 'Compte';

  @override
  String get manageConnections => '🖥️ Gérer connexions & appareils';

  @override
  String get legalSection => 'Légal';

  @override
  String get termsOfService => '📜 Conditions d\'utilisation';

  @override
  String get privacyPolicy => '🔐 Politique de confidentialité';

  @override
  String get legalNoticesItem => '⚖️ Mentions légales';

  @override
  String get logoutTitle => 'Se déconnecter ?';

  @override
  String get logoutMessage => 'Tu vas être déconnecté. Continuer ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get logout => '❌ Se déconnecter';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get deleteAccountWarning =>
      'La suppression du compte est irréversible.';

  @override
  String get deleteMyAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer ton compte ?';

  @override
  String get deleteAccountMessage =>
      'Cette action est irréversible. Toutes tes données (livres, sessions de lecture, badges, amis, groupes) seront définitivement supprimées.';

  @override
  String get continueButton => 'Continuer';

  @override
  String get confirmDeletion => 'Confirmer la suppression';

  @override
  String get typeDeleteToConfirm =>
      'Pour confirmer, tape SUPPRIMER ci-dessous :';

  @override
  String get deleteKeyword => 'SUPPRIMER';

  @override
  String get deleteForever => 'Supprimer définitivement';

  @override
  String errorDeletingAccount(String error) {
    return 'Erreur lors de la suppression : $error';
  }

  @override
  String get editNameTitle => 'Modifier le nom';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String get save => 'Enregistrer';

  @override
  String get nameMinLength => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get nameMaxLength => 'Le nom ne doit pas dépasser 50 caractères';

  @override
  String get nameUpdated => 'Nom mis à jour!';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get chooseFromGallery => 'Choisir dans la galerie';

  @override
  String get imageTooLarge => 'Image trop grande. Taille maximum: 5MB';

  @override
  String get unsupportedFormat =>
      'Format non supporté. Utilisez JPG, PNG ou WebP';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get profilePictureUpdated => '✅ Photo de profil mise à jour!';

  @override
  String timeAgoMinutes(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String timeAgoHours(int hours) {
    return 'il y a ${hours}h';
  }

  @override
  String timeAgoDays(int days) {
    return 'il y a ${days}j';
  }

  @override
  String get libraryEmpty => 'Votre bibliothèque est vide';

  @override
  String get sessionAbandoned => 'Session abandonnée';

  @override
  String get muse => '💡 Muse';

  @override
  String get newBook => 'Nouveau livre';

  @override
  String get myLibraryFab => 'Ma bibliothèque';

  @override
  String get searchEllipsis => 'Rechercher...';

  @override
  String get noBookFound => 'Aucun livre trouvé';

  @override
  String get abandonSessionTitle => 'Abandonner la session';

  @override
  String get abandonSessionMessage =>
      'Voulez-vous vraiment abandonner cette session de lecture ?';

  @override
  String get no => 'Non';

  @override
  String get yes => 'Oui';

  @override
  String get leaveSessionTitle => 'Quitter la session';

  @override
  String get leaveSessionMessage =>
      'La session reste active. Vous pourrez la terminer plus tard.';

  @override
  String get stay => 'Rester';

  @override
  String get leave => 'Quitter';

  @override
  String get sessionInProgress => 'SESSION EN COURS';

  @override
  String get cancelSessionTitle => 'Annuler la session';

  @override
  String get cancelSessionMessage =>
      'Êtes-vous sûr de vouloir annuler cette session de lecture ?';

  @override
  String errorCapture(String error) {
    return 'Erreur lors de la capture: $error';
  }

  @override
  String get errorGoogleBooks => 'Erreur recherche Google Books';

  @override
  String get termsOfServiceTitle => 'Conditions d\'utilisation';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get legalNoticesTitle => 'Mentions légales';

  @override
  String get iAcceptTerms => 'J\'accepte les conditions';
}
