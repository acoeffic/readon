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
  String get systemTheme => '📱 Automatique';

  @override
  String get systemThemeActive => '📱 Automatique (actif)';

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
  String get spanish => '🇪🇸 Español';

  @override
  String get spanishActive => '🇪🇸 Español (activo)';

  @override
  String get accountSection => 'Compte';

  @override
  String get manageConnections => '🖥️ Gérer connexions & appareils';

  @override
  String get legalSection => 'Légal';

  @override
  String get termsOfService => '📜 Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

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

  @override
  String get sessionDuration => 'DURÉE DE SESSION';

  @override
  String get startPage => 'Page de départ';

  @override
  String get streakLabel => 'Série';

  @override
  String streakDays(int days) {
    return '$days jours';
  }

  @override
  String get endSessionSlide => 'Terminer la session';

  @override
  String get abandonButton => 'Abandonner';

  @override
  String get newAnnotation => 'Nouvelle annotation';

  @override
  String get annotationText => 'Texte';

  @override
  String get annotationPhoto => 'Photo';

  @override
  String get annotationVoice => 'Vocal';

  @override
  String get retakePhoto => 'Reprendre la photo';

  @override
  String get extractingText => 'Extraction du texte...';

  @override
  String get micPermissionRequired => 'Permission microphone requise';

  @override
  String get tapToRecord => 'Appuyez pour enregistrer';

  @override
  String get recordingInProgress => 'Enregistrement en cours...';

  @override
  String get retakeRecording => 'Refaire';

  @override
  String get transcriptionInProgress => 'Transcription en cours...';

  @override
  String get hintExtractedText => 'Texte extrait (modifiable)...';

  @override
  String get hintTranscription => 'Transcription (modifiable)...';

  @override
  String get hintAnnotation => 'Notez votre pensée, une citation...';

  @override
  String get voiceAnnotationSaved => 'Annotation vocale sauvegardée !';

  @override
  String get annotationSaved => 'Annotation sauvegardée !';

  @override
  String get transcribing => 'Transcription...';

  @override
  String get pageHint => 'Page';

  @override
  String errorSelection(String error) {
    return 'Erreur lors de la sélection: $error';
  }

  @override
  String get pageNotDetected =>
      'Numéro de page non détecté. Saisissez-le manuellement.';

  @override
  String get pageNotDetectedManual =>
      'Numéro de page non détecté. Vous pouvez le saisir manuellement ci-dessous.';

  @override
  String endPageBeforeStartDetailed(int endPage, int startPage) {
    return 'La page de fin ($endPage) ne peut pas être avant la page de début ($startPage).';
  }

  @override
  String ocrError(String error) {
    return 'Erreur OCR: $error';
  }

  @override
  String get invalidPageNumber => 'Veuillez saisir un numéro de page valide.';

  @override
  String get captureOrEnterPage =>
      'Veuillez capturer une photo ou saisir un numéro de page.';

  @override
  String get endPageBeforeStart =>
      'La page de fin ne peut pas être avant la page de début.';

  @override
  String get finishBookTitle => 'Terminer le livre';

  @override
  String get finishBookConfirm => 'Félicitations! Avez-vous terminé ce livre ?';

  @override
  String get yesFinished => 'Oui, terminé!';

  @override
  String get endReading => 'Terminer la lecture';

  @override
  String get currentSession => 'Session en cours';

  @override
  String startedAtPage(int page) {
    return 'Commencée à la page $page';
  }

  @override
  String durationValue(String duration) {
    return 'Durée: $duration';
  }

  @override
  String get instructions => 'Instructions';

  @override
  String get instructionEndPhoto => '1. Photographiez votre dernière page lue';

  @override
  String get instructionEndVisible =>
      '2. Assurez-vous que le numéro est visible';

  @override
  String get instructionEndValidate =>
      '3. Validez pour enregistrer votre progression';

  @override
  String get instructionStartPhoto =>
      '1. Photographiez la page où vous commencez';

  @override
  String get instructionStartVisible =>
      '2. Assurez-vous que le numéro de page est visible';

  @override
  String get instructionStartOcr =>
      '3. L\'OCR détectera automatiquement le numéro';

  @override
  String get takePhotoBtn => 'Prendre Photo';

  @override
  String get galleryBtn => 'Galerie';

  @override
  String get analyzing => 'Analyse en cours...';

  @override
  String get photoCaptured => 'Photo capturée:';

  @override
  String get pageCorrected => 'Page corrigée:';

  @override
  String get pageDetected => 'Page détectée:';

  @override
  String pagesReadCount(int count) {
    return 'Pages lues: $count';
  }

  @override
  String get correctNumber => 'Corriger le numéro';

  @override
  String get pageNumberLabel => 'Numéro de page';

  @override
  String startPagePrefix(int page) {
    return 'Page de début: $page';
  }

  @override
  String get validate => 'Valider';

  @override
  String get orEnterManually => 'Ou saisissez le numéro directement:';

  @override
  String get startReadingTitle => 'Démarrer une lecture';

  @override
  String get sessionAlreadyActive => 'Une session est déjà en cours';

  @override
  String get resumeSession => 'Reprendre la session';

  @override
  String get startReadingSession => 'Démarrer la session de lecture';

  @override
  String get congratulations => 'Félicitations!';

  @override
  String get bookFinishedExcl => 'Livre terminé!';

  @override
  String get continueExcl => 'Continuer!';

  @override
  String get flowBadgeTitle => 'Badge Flow!';

  @override
  String consecutiveDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$days jour$_temp0 consécutif$_temp1!';
  }

  @override
  String museBookFinished(String title) {
    return 'Bravo pour $title ! Envie que Muse te conseille ta prochaine lecture ?';
  }

  @override
  String get later => 'Plus tard';

  @override
  String get chatWithMuse => 'Discuter avec Muse';

  @override
  String get defaultUser => 'Utilisateur';

  @override
  String get mySessions => 'Mes Sessions';

  @override
  String get myStatistics => 'Statistiques';

  @override
  String get myLists => 'Mes Listes';

  @override
  String get statistics => 'Statistiques';

  @override
  String get readingStatistics => 'Statistiques de lecture';

  @override
  String get featureComingSoon => 'Fonctionnalité à venir';

  @override
  String get cannotAddBook => 'Impossible d\'ajouter ce livre';

  @override
  String get titleAuthorPagesRequired => 'Titre, auteur et pages requis';

  @override
  String get bookAdded => 'Livre ajouté';

  @override
  String get errorAdding => 'Erreur lors de l\'ajout';

  @override
  String get addBookTitle => 'Ajouter un livre';

  @override
  String get googleBooksSearchTitle => 'Recherche Google Books';

  @override
  String get titleAuthorIsbn => 'Titre, auteur ou ISBN';

  @override
  String get noTitleDefault => 'Sans titre';

  @override
  String get addButton => 'Ajouter';

  @override
  String get manualAdd => 'Ajout manuel';

  @override
  String get titleHint => 'Titre';

  @override
  String get authorHint => 'Auteur';

  @override
  String get totalPages => 'Pages totales';

  @override
  String get activeSessionDialogTitle => 'Session en cours';

  @override
  String get activeSessionDialogMessage =>
      'Une session de lecture est déjà en cours pour ce livre.';

  @override
  String pageAtNumber(int page) {
    return 'Page $page';
  }

  @override
  String get whatDoYouWant => 'Que voulez-vous faire ?';

  @override
  String get resume => 'Reprendre';

  @override
  String get sessionCompleted => 'SESSION TERMINÉE';

  @override
  String get sessionCompletedTitle => 'Session terminée !';

  @override
  String get myReadingDefault => 'Ma lecture';

  @override
  String get durationStatLabel => 'durée';

  @override
  String get pagesReadStatLabel => 'pages lues';

  @override
  String get streakStatLabel => 'série';

  @override
  String streakDaysShort(int days) {
    return '$days j.';
  }

  @override
  String get readingPace => 'Rythme de lecture';

  @override
  String get avgTimePerPage => 'Temps moyen par page';

  @override
  String get estimatedBookEnd => 'Fin estimée du livre';

  @override
  String get vsYourAverage => 'vs. ta moyenne';

  @override
  String fasterPercent(int percent) {
    return '+$percent% plus rapide';
  }

  @override
  String slowerPercent(int percent) {
    return '$percent% plus lent';
  }

  @override
  String get withinAverage => 'Dans ta moyenne';

  @override
  String get sessionInsights => 'Insights de la session';

  @override
  String get viewFullReport => '✨ Voir le bilan complet';

  @override
  String get paceAndTrends => 'Rythme, tendances, estimation de fin et plus';

  @override
  String get tryPremium => 'Essayer';

  @override
  String get shareSession => 'Partager la session';

  @override
  String get hideSession => 'Masquer cette session';

  @override
  String get sessionHiddenFromRankings => 'Session masquée des classements';

  @override
  String get errorHidingSession => 'Erreur lors du masquage';

  @override
  String get skip => 'Passer';

  @override
  String nPages(int count) {
    return '$count pages';
  }

  @override
  String get bookCompletedHeader => 'LIVRE TERMINÉ';

  @override
  String get bookCompletedTitle => 'Livre terminé !';

  @override
  String get congratsFinished => 'Félicitations, tu as terminé';

  @override
  String get completed => 'Terminé';

  @override
  String get ofReading => 'de lecture';

  @override
  String get sessions => 'sessions';

  @override
  String readingDaysCount(int count) {
    return '$count jours de lecture';
  }

  @override
  String get bookReport => 'Bilan du livre';

  @override
  String get avgPace => 'Rythme moyen';

  @override
  String get preferredSlot => 'Créneau préféré';

  @override
  String get bestSession => 'Meilleure session';

  @override
  String get readingRegularity => 'Régularité de lecture';

  @override
  String get morningSlot => 'Matin (6h–12h)';

  @override
  String get afternoonSlot => 'Après-midi (12h–18h)';

  @override
  String get eveningSlot => 'Soir (18h–22h)';

  @override
  String get nightSlot => 'Nuit (22h–6h)';

  @override
  String get unknownSlot => 'Inconnu';

  @override
  String pagesInDuration(int pages, String duration) {
    return '$pages pages en $duration';
  }

  @override
  String daysPerWeek(String count) {
    return '$count j/sem';
  }

  @override
  String get unlockedBadges => 'Badges débloqués';

  @override
  String get share => 'Partager';

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get paceAndSlots => 'Rythme, créneaux, régularité et plus';

  @override
  String get clubSubtitle => 'communauté';

  @override
  String get readingClubs => 'Clubs de lecture';

  @override
  String get readingClub => 'Club de lecture';

  @override
  String get myClubs => 'Mes clubs';

  @override
  String get myGroups => 'Mes groupes';

  @override
  String get discover => 'Découvrir';

  @override
  String get createClub => 'Créer un Club';

  @override
  String get noGroups => 'Aucun groupe';

  @override
  String get createOrJoinGroup => 'Créez ou rejoignez un groupe de lecture';

  @override
  String get noPublicGroups => 'Aucun groupe public';

  @override
  String get beFirstToCreate => 'Soyez le premier à créer un groupe public !';

  @override
  String get privateTag => 'Privé';

  @override
  String get adminTag => 'Admin';

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count membre$_temp0';
  }

  @override
  String byCreator(String name) {
    return 'par $name';
  }

  @override
  String get limitReached => 'Limite atteinte';

  @override
  String groupLimitMessage(int max) {
    return 'Tu as atteint la limite de $max clubs de lecture. Passe à Premium pour en rejoindre autant que tu veux !';
  }

  @override
  String get becomePremium => 'Devenir Premium';

  @override
  String get leaveGroupTitle => 'Quitter le groupe ?';

  @override
  String get leaveGroupMessage => 'Voulez-vous vraiment quitter ce groupe ?';

  @override
  String get leftGroup => 'Vous avez quitté le groupe';

  @override
  String get groupNotFound => 'Groupe introuvable';

  @override
  String get members => 'Membres';

  @override
  String get activities => 'Activités';

  @override
  String get activeChallenges => 'Défis actifs';

  @override
  String get createChallenge => 'Créer un défi';

  @override
  String get noChallengeActive => 'Aucun défi actif';

  @override
  String get groupActivities => 'Activités du groupe';

  @override
  String get noActivity => 'Aucune activité';

  @override
  String get activitiesWillAppear =>
      'Les activités des membres apparaîtront ici';

  @override
  String readPagesOf(int pages, String title) {
    return 'a lu $pages pages de \"$title\"';
  }

  @override
  String finishedBook(String title) {
    return 'a terminé \"$title\" 🎉';
  }

  @override
  String get joinedGroup => 'a rejoint le groupe';

  @override
  String recommendsBook(String title) {
    return 'recommande \"$title\"';
  }

  @override
  String get unknownActivity => 'activité inconnue';

  @override
  String get justNow => 'À l\'instant';

  @override
  String get createGroupTitle => 'Créer un groupe';

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get groupNameRequired => 'Nom du groupe *';

  @override
  String get groupNameHint => 'Ex: Club des lecteurs SF';

  @override
  String get nameRequired => 'Le nom est requis';

  @override
  String get descriptionOptional => 'Description (optionnel)';

  @override
  String get describeGroup => 'Décrivez votre groupe de lecture...';

  @override
  String get privateGroup => 'Groupe privé';

  @override
  String get inviteOnly => 'Uniquement accessible sur invitation';

  @override
  String get visibleToAll => 'Visible par tous les utilisateurs';

  @override
  String get creatorAdminInfo =>
      'En tant que créateur, vous serez automatiquement administrateur du groupe et pourrez inviter d\'autres membres.';

  @override
  String get createGroup => 'Créer le groupe';

  @override
  String get groupCreated => 'Groupe créé avec succès!';

  @override
  String get allFriendsInGroup => 'Tous vos amis sont déjà membres du groupe';

  @override
  String get inviteFriend => 'Inviter un ami';

  @override
  String invitationSent(String name) {
    return '✅ Invitation envoyée à $name';
  }

  @override
  String roleUpdated(String name) {
    return 'Rôle de $name mis à jour';
  }

  @override
  String get removeFromGroupTitle => 'Retirer du groupe ?';

  @override
  String removeFromGroupMessage(String name) {
    return 'Voulez-vous retirer $name du groupe ?';
  }

  @override
  String get removeButton => 'Retirer';

  @override
  String memberRemoved(String name) {
    return '$name a été retiré du groupe';
  }

  @override
  String get demoteToMember => 'Rétrograder en membre';

  @override
  String get promoteAdmin => 'Promouvoir admin';

  @override
  String get removeFromGroup => 'Retirer du groupe';

  @override
  String membersCount(int count) {
    return 'Membres ($count)';
  }

  @override
  String get noMembers => 'Aucun membre';

  @override
  String get youTag => 'Vous';

  @override
  String get administrator => 'Administrateur';

  @override
  String get memberRole => 'Membre';

  @override
  String get photoUpdated => 'Photo mise à jour';

  @override
  String get changesSaved => 'Modifications enregistrées';

  @override
  String get deleteGroupTitle => 'Supprimer le groupe ?';

  @override
  String get deleteGroupMessage =>
      'Cette action est irréversible. Tous les membres seront retirés et les données du groupe seront perdues.';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get confirmDeleteGroupTitle => 'Confirmer la suppression';

  @override
  String confirmDeleteGroupMessage(String name) {
    return 'Voulez-vous vraiment supprimer \"$name\" définitivement ?';
  }

  @override
  String get groupDeleted => 'Groupe supprimé';

  @override
  String get currentReading => 'Lecture du moment';

  @override
  String get noCurrentReading => 'Aucun livre en cours';

  @override
  String get setCurrentReading => 'Définir la lecture du groupe';

  @override
  String get inviteMembers => 'Inviter des membres';

  @override
  String get changeImage => 'Changer l\'image';

  @override
  String get groupSettings => 'Réglages du groupe';

  @override
  String get groupPhoto => 'Photo du groupe';

  @override
  String get information => 'Informations';

  @override
  String get description => 'Description';

  @override
  String get visibility => 'Visibilité';

  @override
  String get publicGroup => 'Groupe public';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get manageMembers => 'Gérer les membres';

  @override
  String get manageMembersSubtitle => 'Voir, inviter et gérer les rôles';

  @override
  String get deleteChallengeTitle => 'Supprimer le défi ?';

  @override
  String get deleteChallengeMessage => 'Cette action est irréversible.';

  @override
  String get challengeDeleted => 'Défi supprimé';

  @override
  String get expired => 'Expiré';

  @override
  String daysRemaining(int days) {
    return '${days}j restants';
  }

  @override
  String hoursRemaining(int hours) {
    return '${hours}h restantes';
  }

  @override
  String minutesRemaining(int minutes) {
    return '${minutes}min restantes';
  }

  @override
  String get readABook => 'Lire un livre';

  @override
  String pagesToRead(int count) {
    return '$count pages à lire';
  }

  @override
  String dailyChallenge(int minutes, int days) {
    return '$minutes min/jour pendant $days jours';
  }

  @override
  String get challengeDetail => 'Détail du défi';

  @override
  String get leaveChallenge => 'Quitter le défi';

  @override
  String get joinChallenge => 'Rejoindre le défi';

  @override
  String get leftChallenge => 'Vous avez quitté le défi';

  @override
  String get joinedChallenge => 'Vous participez au défi !';

  @override
  String participantsCount(int count) {
    return 'Participants ($count)';
  }

  @override
  String get noParticipants => 'Aucun participant';

  @override
  String get challengeCompleted => 'Terminé !';

  @override
  String get challengeInProgress => 'En cours...';

  @override
  String progressPages(int progress, int target) {
    return '$progress / $target pages';
  }

  @override
  String progressDays(int progress, int target) {
    return '$progress / $target jours';
  }

  @override
  String get myProgress => 'Ma progression';

  @override
  String get completedTag => 'Complété';

  @override
  String get newChallenge => 'Nouveau défi';

  @override
  String get challengeType => 'Type de défi';

  @override
  String get challengeTitleRequired => 'Titre du défi *';

  @override
  String get challengeTitleHint => 'Ex: Marathon de lecture';

  @override
  String get titleRequired => 'Le titre est requis';

  @override
  String get startDate => 'Date de début';

  @override
  String get startsOn => 'Commence le';

  @override
  String get startsToday => 'Aujourd\'hui';

  @override
  String get upcoming => 'À venir';

  @override
  String daysUntilStart(int days) {
    return 'Dans ${days}j';
  }

  @override
  String get challengeStartNotifTitle => 'Le défi commence aujourd\'hui !';

  @override
  String get deadline => 'Date limite';

  @override
  String get createChallengeBtn => 'Créer le défi';

  @override
  String get challengeCreated => 'Défi créé !';

  @override
  String get pagesType => 'Pages';

  @override
  String get bookType => 'Livre';

  @override
  String get dailyType => 'Quotidien';

  @override
  String get bookToRead => 'Livre à lire';

  @override
  String get goalLabel => 'Objectif';

  @override
  String get pagesCountRequired => 'Nombre de pages *';

  @override
  String get pagesCountHint => 'Ex: 200';

  @override
  String get pagesUnit => 'pages';

  @override
  String get required => 'Requis';

  @override
  String get invalidNumber => 'Nombre invalide';

  @override
  String get dailyGoal => 'Objectif quotidien';

  @override
  String get dailyMinutesRequired => 'Minutes de lecture par jour *';

  @override
  String get dailyMinutesHint => 'Ex: 30';

  @override
  String get minPerDay => 'min/jour';

  @override
  String get daysCountRequired => 'Nombre de jours *';

  @override
  String get daysCountHint => 'Ex: 7';

  @override
  String get daysUnit => 'jours';

  @override
  String get oneWeek => '1 sem.';

  @override
  String get twoWeeks => '2 sem.';

  @override
  String get oneMonth => '1 mois';

  @override
  String get expiresOn => 'Expire le';

  @override
  String get chooseBook => 'Choisir un livre';

  @override
  String get searchBookHint => 'Rechercher un livre...';

  @override
  String get noResult => 'Aucun résultat';

  @override
  String get selectBookPrompt => 'Veuillez sélectionner un livre';

  @override
  String readBookTitle(String title) {
    return 'Lire \"$title\"';
  }

  @override
  String get privateProfileLabel => 'Profil privé';

  @override
  String privateProfileMessage(String name) {
    return 'Ce profil est privé. Ajoutez $name en ami pour voir ses statistiques.';
  }

  @override
  String get books => 'Livres';

  @override
  String get viewFullProfile => 'Voir le profil complet';

  @override
  String get followLabel => 'Ajouter cet ami';

  @override
  String get pagesLabel => 'Pages';

  @override
  String get readingLabel => 'Lecture';

  @override
  String get flowLabel => 'Flow';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get noRecentActivity => 'Aucune activité récente';

  @override
  String get theirBadges => 'Ses badges';

  @override
  String get removeFriend => 'Retirer des amis';

  @override
  String get cancelRequest => 'Annuler la demande';

  @override
  String get addFriend => 'Ajouter en ami';

  @override
  String get removeFriendTitle => 'Retirer cet ami ?';

  @override
  String removeFriendMessage(String name) {
    return 'Voulez-vous retirer $name de vos amis ?';
  }

  @override
  String get requestSent => 'Demande envoyée';

  @override
  String get requestCancelled => 'Demande annulée';

  @override
  String get friendRemoved => 'Ami retiré';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String daysAgo(int days) {
    return 'Il y a $days jours';
  }

  @override
  String get myFriends => 'Mes amis';

  @override
  String get findFriends => 'Trouver des amis';

  @override
  String get retry => 'Réessayer';

  @override
  String get noFriendFound => 'Aucun ami trouvé';

  @override
  String get addFriendsToSeeActivityMessage =>
      'Ajoutez des amis pour voir leur activité !';

  @override
  String get friendRemovedSnack => 'Ami retiré';

  @override
  String cannotRemoveFriend(String error) {
    return 'Impossible de retirer cet ami: $error';
  }

  @override
  String get searchLabel => 'Rechercher';

  @override
  String get friends => 'Amis';

  @override
  String get groups => 'Groupes';

  @override
  String get searchByName => 'Rechercher par nom';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get inviteToRead => 'Invite tes amis à lire';

  @override
  String get shareWhatYouRead => 'Partage ce que tu lis en ce moment';

  @override
  String get typeMin2Chars => 'Tape au moins 2 caractères pour chercher';

  @override
  String get invitationSentShort => 'Invitation envoyée';

  @override
  String get cannotAddFriend => 'Impossible d\'ajouter cet ami';

  @override
  String get cannotCancelRequest => 'Impossible d\'annuler la demande';

  @override
  String relationAlreadyExists(String status) {
    return 'Relation déjà $status';
  }

  @override
  String get invalidUser => 'Utilisateur invalide';

  @override
  String get connectToAddFriend => 'Connecte-toi pour ajouter un ami';

  @override
  String get errorDuringSearch => 'Erreur lors de la recherche';

  @override
  String get firstSessionBravo =>
      'Bravo pour ta première\nsession de lecture !';

  @override
  String get friendsReadToo =>
      'Tes amis lisent aussi.\nAjoute-les pour voir leur activité !';

  @override
  String get findMyFriends => 'Trouver mes amis';

  @override
  String get searchingContacts => 'Recherche de tes amis...';

  @override
  String get noContactOnLexDay => 'Aucun contact n\'utilise encore LexDay';

  @override
  String friendsFoundOnLexDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count ami$_temp0 trouvé$_temp1 sur LexDay';
  }

  @override
  String get inviteFriendsToJoin => 'Invite tes amis à rejoindre LexDay !';

  @override
  String get sent => 'Envoyé';

  @override
  String get contactsAccessDenied => 'Accès aux contacts refusé';

  @override
  String get cannotAccessContacts => 'Impossible d\'accéder aux contacts';

  @override
  String get authorizeContactsSettings =>
      'Pour trouver tes amis, autorise l\'accès aux contacts dans les réglages.';

  @override
  String get errorOccurredRetryLater =>
      'Une erreur est survenue. Réessaie plus tard.';

  @override
  String get openSettings => 'Ouvrir les réglages';

  @override
  String get findContactsFriends => 'Trouver des amis';

  @override
  String get searchingYourContacts => 'Recherche dans tes contacts...';

  @override
  String get noContactFound => 'Aucun contact trouvé';

  @override
  String get contactsNotOnLexDay =>
      'Tes contacts ne semblent pas encore utiliser LexDay.';

  @override
  String get alreadyOnLexDay => 'Déjà sur LexDay';

  @override
  String get inviteToLexDay => 'Inviter sur LexDay';

  @override
  String get invited => 'Invité';

  @override
  String get invite => 'Inviter';

  @override
  String get authorizeContacts =>
      'Pour trouver tes amis, autorise l\'accès à tes contacts.';

  @override
  String get cannotAccessContactsRetry =>
      'Impossible d\'accéder à tes contacts. Réessaie plus tard.';

  @override
  String get errorOccurred => 'Une erreur est survenue';

  @override
  String get shareInviteToLexDay =>
      'Rejoins-moi sur LexDay pour suivre nos lectures ensemble ! Télécharge l\'app : https://readon.app';

  @override
  String get friendRequests => 'Demandes d\'amis';

  @override
  String get cannotGetRequests => 'Impossible de récupérer les demandes';

  @override
  String get friendAdded => 'Ami ajouté';

  @override
  String get requestDeclined => 'Demande refusée';

  @override
  String get actionImpossible => 'Action impossible';

  @override
  String get noRequest => 'Aucune demande';

  @override
  String get museGreeting =>
      'Salut, je suis Muse, ta conseillère lecture. Qu\'as-tu envie de lire ?';

  @override
  String get museRecommendNovel => 'Recommande-moi un roman';

  @override
  String get museSimilarBook => 'Un livre similaire à mon dernier';

  @override
  String get museClassic => 'Un classique à découvrir';

  @override
  String freeMessagesUsed(int max) {
    return 'Tu as utilisé tes $max messages gratuits ce mois-ci';
  }

  @override
  String get subscribeForUnlimited =>
      'Abonne-toi pour discuter sans limite avec Muse !';

  @override
  String get discoverSubscription => 'Découvrir l\'abonnement';

  @override
  String get askRecommendation => 'Demande une recommandation...';

  @override
  String cannotLoadBook(String error) {
    return 'Impossible de charger le livre : $error';
  }

  @override
  String get inBookstore => 'En librairie';

  @override
  String get findNearMe => 'Trouver près de moi';

  @override
  String get enableLocationSettings =>
      'Activez la localisation dans les réglages';

  @override
  String get locationAccessRequired => 'Accès à la localisation requis';

  @override
  String get addToList => 'Ajouter à une liste';

  @override
  String get noPersonalList => 'Aucune liste personnelle.';

  @override
  String get createNewList => 'Créer une nouvelle liste';

  @override
  String addedToList(String title) {
    return 'Ajouté à \"$title\"';
  }

  @override
  String get deleteConversation => 'Supprimer la conversation';

  @override
  String get deleteConversationConfirm =>
      'Es-tu sûr de vouloir supprimer cette conversation ?';

  @override
  String get unlimitedChatbot =>
      'Utilisation illimitée du chatbot, abonnez-vous';

  @override
  String messagesUsedCount(int used, int max) {
    return '$used/$max messages utilisés ce mois-ci';
  }

  @override
  String get noConversation => 'Aucune conversation';

  @override
  String get startConversationMuse =>
      'Démarre une conversation avec Muse pour obtenir des recommandations de livres personnalisées.';

  @override
  String get newConversation => 'Nouvelle conversation';

  @override
  String get readingLists => 'Listes de lecture';

  @override
  String nBooks(int count) {
    return '$count livres';
  }

  @override
  String nReaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count lecteur$_temp0';
  }

  @override
  String nRead(int read, int total) {
    return '$read/$total lus';
  }

  @override
  String get deleteListTitle => 'Supprimer cette liste ?';

  @override
  String deleteListMessage(String title) {
    return 'La liste \"$title\" sera définitivement supprimée.';
  }

  @override
  String get editButton => 'Modifier';

  @override
  String get addBookToList => 'Ajouter un livre';

  @override
  String get noBooksInList => 'Aucun livre dans cette liste';

  @override
  String get addBooksFromLibrary =>
      'Ajoute des livres depuis ta bibliothèque ou en recherchant un titre.';

  @override
  String get removeBookTitle => 'Retirer ce livre ?';

  @override
  String removeBookMessage(String title) {
    return 'Retirer \"$title\" de cette liste ?';
  }

  @override
  String get removeFromLibraryTitle => 'Supprimer de ma bibliothèque ?';

  @override
  String removeFromLibraryMessage(String title) {
    return 'Supprimer \"$title\" définitivement de ta bibliothèque ?';
  }

  @override
  String get removeFromLibraryAction => 'Supprimer';

  @override
  String get bookRemovedFromLibrary => 'Livre supprimé de ta bibliothèque';

  @override
  String get myListsSection => 'Mes listes';

  @override
  String get savedLists => 'Listes sauvegardées';

  @override
  String get noList => 'Aucune liste';

  @override
  String get createListCta =>
      'Crée ta propre liste de lecture ou découvre nos sélections curatées.';

  @override
  String get createList => 'Créer une liste';

  @override
  String listLimitMessage(int max) {
    return 'Tu as atteint la limite de $max listes de lecture. Passe à Premium pour en créer autant que tu veux !';
  }

  @override
  String get ok => 'OK';

  @override
  String get goPremium => 'Passer Premium';

  @override
  String get editList => 'Modifier la liste';

  @override
  String get newList => 'Nouvelle liste';

  @override
  String get listName => 'Nom de la liste';

  @override
  String get listNameHint => 'Ex : Livres à lire cet été';

  @override
  String get iconLabel => 'Icône';

  @override
  String get colorLabel => 'Couleur';

  @override
  String get createListBtn => 'Créer la liste';

  @override
  String get defaultListName => 'Ma liste';

  @override
  String get publicList => 'Liste publique';

  @override
  String get privateList => 'Liste privée';

  @override
  String get publicListDescription => 'Visible par tes amis sur ton profil';

  @override
  String get privateListDescription => 'Visible uniquement par toi';

  @override
  String get addBooksTitle => 'Ajouter des livres';

  @override
  String get myLibraryTab => 'Ma bibliothèque';

  @override
  String get searchTab => 'Rechercher';

  @override
  String get emptyLibrary => 'Bibliothèque vide';

  @override
  String get useSearchTab =>
      'Utilise l\'onglet Rechercher pour trouver et ajouter des livres.';

  @override
  String get filterLibrary => 'Filtrer ma bibliothèque...';

  @override
  String get searchTitleAuthor => 'Rechercher un titre ou un auteur...';

  @override
  String get tryMoreSpecific => 'Essaie avec un titre plus précis';

  @override
  String get searchByTitleAuthor => 'Recherche un livre par titre ou auteur';

  @override
  String get noReadingSession => 'Aucune session de lecture';

  @override
  String get startSessionPrompt => 'Lancez une session pour commencer !';

  @override
  String get unknownBook => 'Livre inconnu';

  @override
  String get inProgressTag => 'En cours';

  @override
  String nPagesRead(int count) {
    return '$count pages';
  }

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisMonth => 'Ce mois';

  @override
  String get sessionTag => 'SESSION';

  @override
  String get makeVisible => 'Rendre visible';

  @override
  String get hideSessionBtn => 'Masquer la session';

  @override
  String get sessionHiddenInfo => 'Session masquée des classements et du feed';

  @override
  String get bookProgression => 'Progression du livre';

  @override
  String get durationLabel => 'durée';

  @override
  String get pagesReadLabel => 'pages lues';

  @override
  String get paceLabel => 'rythme';

  @override
  String get sessionProgression => 'Progression de la session';

  @override
  String plusPages(int count) {
    return '+$count pages';
  }

  @override
  String get startLabel => 'Début';

  @override
  String get endLabel => 'Fin';

  @override
  String get timeline => 'Chronologie';

  @override
  String get sessionStart => 'début de session';

  @override
  String ofReadingDuration(String duration) {
    return '$duration de lecture';
  }

  @override
  String get sessionEnd => 'fin de session';

  @override
  String get unlockInsights => '✨ Débloquer tes insights';

  @override
  String get deleteSessionTitle => 'Supprimer la session';

  @override
  String get deleteSessionMessage =>
      'Voulez-vous vraiment supprimer cette session de lecture ? Cette action est irréversible.';

  @override
  String get sessionVisible => 'Session visible dans les classements';

  @override
  String get errorModifying => 'Erreur lors de la modification';

  @override
  String get errorDeleting => 'Erreur lors de la suppression';

  @override
  String get loadingError => 'Erreur de chargement';

  @override
  String get pagesReadByMonth => 'Pages lues par mois';

  @override
  String get genreDistribution => 'Répartition des genres';

  @override
  String get whenDoYouRead => 'Quand lis-tu';

  @override
  String get favoriteSchedules => 'Tes horaires favoris de la semaine';

  @override
  String get yourGoals => 'Tes objectifs';

  @override
  String get noGoalDefined => 'Aucun objectif défini';

  @override
  String get defineGoals => 'Définir tes objectifs';

  @override
  String get notifications => 'Notifications';

  @override
  String get readingReminders => 'Rappels de lecture';

  @override
  String get remindersDescription =>
      'Reste motivé avec des rappels quotidiens pour maintenir ton flow de lecture.';

  @override
  String get enableNotifications => 'Activer les notifications';

  @override
  String get receiveDailyReminders => 'Reçois des rappels quotidiens';

  @override
  String get reminderDays => 'Jours de rappel';

  @override
  String get whichDays => 'Quels jours veux-tu être notifié ?';

  @override
  String get reminderTime => 'Heure du rappel';

  @override
  String get whenReminder => 'Quand veux-tu recevoir le rappel ?';

  @override
  String get aboutNotifications => 'À propos des notifications';

  @override
  String get notificationInfo =>
      'Tu recevras une notification les jours sélectionnés pour te rappeler de lire et maintenir ton flow.';

  @override
  String get notificationCenter => 'Centre de notifications';

  @override
  String get notificationCenterDescription =>
      'Gère tes préférences de notifications.';

  @override
  String get friendRequestNotifications => 'Demandes d\'ami';

  @override
  String get friendRequestNotificationsDesc =>
      'Être notifié des nouvelles demandes d\'ami';

  @override
  String get emailSection => 'Emails';

  @override
  String get emailSectionDescription =>
      'Choisis les notifications que tu veux recevoir par email.';

  @override
  String get friendRequestEmail => 'Demandes d\'ami par email';

  @override
  String get friendRequestEmailDesc =>
      'Recevoir un email quand quelqu\'un t\'envoie une demande d\'ami';

  @override
  String get pushSection => 'Notifications push';

  @override
  String get pushSectionDescription => 'Notifications sur ton appareil.';

  @override
  String get settingsSaved => 'Préférences enregistrées';

  @override
  String get myGoals => 'Mes objectifs';

  @override
  String get goalsDescription =>
      'Personnalise tes objectifs pour rester motivé et suivre ta progression.';

  @override
  String get goalsSaved => 'Objectifs enregistrés !';

  @override
  String get freeGoal => 'Objectif libre';

  @override
  String get selectedGoals => '💡 Objectifs sélectionnés';

  @override
  String get goalPrefix => 'Objectif :';

  @override
  String get saveMyGoals => 'Enregistrer mes objectifs';

  @override
  String get goalsModifiable =>
      'Tu pourras modifier tes objectifs à tout moment';

  @override
  String get upgradeToLabel => 'Passez à';

  @override
  String get lexdayPremium => 'LexDay Premium';

  @override
  String get unlockPotential => 'Débloquez tout le potentiel de votre lecture';

  @override
  String get whatPremiumUnlocks => 'Ce que Premium débloque';

  @override
  String get seeLess => 'Voir moins';

  @override
  String moreFeatures(int count) {
    return '+$count fonctionnalités';
  }

  @override
  String get choosePlan => 'Choisir un plan';

  @override
  String get cannotLoadOffers => 'Impossible de charger les offres';

  @override
  String get startFreeTrial => 'Commencer l\'essai gratuit';

  @override
  String get subscribe => 'S\'abonner';

  @override
  String get freeTrialInfo =>
      'Essai gratuit de 7 jours. Aucun paiement immédiat.\nAnnulable à tout moment.';

  @override
  String get monthlyBillingInfo =>
      'Facturé chaque mois. Annulable à tout moment.';

  @override
  String get restorePurchases => 'Restaurer mes achats';

  @override
  String get termsOfUse => 'Conditions d\'utilisation';

  @override
  String get welcomePremium => 'Bienvenue dans LexDay Premium !';

  @override
  String get subscriptionRestored => 'Abonnement restauré !';

  @override
  String get noSubscriptionFound => 'Aucun abonnement trouvé';

  @override
  String get featureHeader => 'FONCTIONNALITÉ';

  @override
  String get freeHeader => 'GRATUIT';

  @override
  String get premiumHeader => 'PREMIUM';

  @override
  String get alreadyFree => 'DÉJÀ INCLUS GRATUITEMENT';

  @override
  String get annual => 'Annuel';

  @override
  String get monthly => 'Mensuel';

  @override
  String get yourReadingFlow => 'Ton flow de lecture';

  @override
  String consecutiveDaysActive(int days) {
    return '$days jours consécutifs, actif';
  }

  @override
  String get daysLabel => 'jours';

  @override
  String get currentFlow => 'Flow actuel';

  @override
  String get totalDays => 'jours au total';

  @override
  String get recordDays => 'jours au record';

  @override
  String get flowFreeze => 'Flow Freeze';

  @override
  String get autoFreezeActive => 'Auto-freeze actif';

  @override
  String get protect => 'Protéger';

  @override
  String get unlimited => 'Illimité';

  @override
  String freezesAvailable(int count) {
    return '$count/2 dispo';
  }

  @override
  String get exhausted => 'Épuisé';

  @override
  String get premiumAutoFreezes =>
      'Passe Premium pour des auto-freezes illimités et le freeze manuel.';

  @override
  String get useFreezeTitle => 'Utiliser le freeze ?';

  @override
  String get useFreezeMessage =>
      'Cela protégera ton flow pour hier en utilisant un freeze manuel.';

  @override
  String get flowHistory => 'Historique du flow';

  @override
  String get flowHistoryDescription =>
      'Navigue dans tout ton historique de lecture mois par mois';

  @override
  String get unlockWithPremium => 'Débloquer avec Premium';

  @override
  String beatPercentile(int percentile) {
    return 'Tu as battu $percentile % des lecteurs réguliers.';
  }

  @override
  String get bravoExcl => 'Bravo! ';

  @override
  String get keepReadingTomorrow =>
      'Continue ta lecture demain pour maintenir ton flow!';

  @override
  String get iAcceptThe => 'J\'accepte les ';

  @override
  String get termsOfUseLink => 'Conditions Générales d\'Utilisation';

  @override
  String get ofLexDay => ' de LexDay';

  @override
  String readingNow(String label) {
    return 'En train de lire · $label';
  }

  @override
  String get amazon => 'Amazon';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get librarySubtitle => 'ta collection';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterReading => 'En cours';

  @override
  String get filterRead => 'Lu';

  @override
  String get filterMyLists => 'Mes listes';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get currentlyReading => 'En cours';

  @override
  String get readBooks => 'Lu';

  @override
  String get noCurrentlyReading => 'Aucun livre en cours';

  @override
  String get noReadBooks => 'Aucun livre lu';

  @override
  String get allReadingBooks => 'Livres en cours';

  @override
  String get allFinishedBooks => 'Livres lus';

  @override
  String get newSessionSubtitle => 'NOUVELLE SESSION';

  @override
  String get startSessionTitle => 'Démarrer';

  @override
  String get whatPageAreYouAt => 'À QUELLE PAGE ES-TU ?';

  @override
  String get scanPageBtn => 'Scanner la page';

  @override
  String get galleryPageBtn => 'Galerie';

  @override
  String get launchSessionBtn => 'Lancer la session';

  @override
  String continueFromPage(int page) {
    return 'Continuer depuis la page $page';
  }

  @override
  String lastSessionPage(int page) {
    return 'Dernière session — page $page';
  }

  @override
  String pagesProgress(int current, int total) {
    return '$current / $total pages';
  }

  @override
  String get noPreviousSession => 'Première session';

  @override
  String sharedByUser(String name) {
    return 'Partagé par $name';
  }

  @override
  String get sessionAnnotations => 'Annotations de la session';

  @override
  String get annotateButton => 'Annoter';

  @override
  String get comments => 'Commentaires';

  @override
  String get writeComment => 'Écrire un commentaire...';

  @override
  String get commentBeingValidated => 'Commentaire en cours de validation...';

  @override
  String get commentPending => 'En attente';

  @override
  String get noCommentsYet => 'Aucun commentaire pour le moment';

  @override
  String get beFirstToComment => 'Sois le premier à commenter !';

  @override
  String get send => 'Envoyer';

  @override
  String get reactionPremiumOnly => 'Réaction réservée aux membres Premium';

  @override
  String get nearbyBookstores => 'Librairies proches';

  @override
  String get noBookstoresFound => 'Aucune librairie trouvée à proximité';

  @override
  String get openNow => 'Ouvert';

  @override
  String get closed => 'Fermé';

  @override
  String get navigate => 'Itinéraire';

  @override
  String get searchingBookstores => 'Recherche de librairies...';

  @override
  String get loadMoreBookstores => 'Voir plus de librairies';

  @override
  String get offlineBanner =>
      'Hors ligne — les sessions seront synchronisées automatiquement';

  @override
  String get sessionSavedOffline =>
      'Session enregistrée hors ligne. Elle sera synchronisée à la reconnexion.';

  @override
  String offlineSyncSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions synchronisées',
      one: '1 session synchronisée',
    );
    return '$_temp0';
  }

  @override
  String get markAllRead => 'Tout lire';

  @override
  String get newNotifications => 'Nouvelles';

  @override
  String get recentNotifications => 'Récentes';

  @override
  String get noNotifications => 'Aucune notification';

  @override
  String get noNotificationsDesc =>
      'Tu seras notifié des likes, commentaires et demandes d\'amis';

  @override
  String get notifTypeFriends => 'Amis';

  @override
  String get notifTypeLike => 'Like';

  @override
  String get notifTypeComment => 'Commentaire';

  @override
  String get notifTypeClub => 'Club';

  @override
  String get accept => 'Accepter';

  @override
  String get ignore => 'Ignorer';

  @override
  String sentYouFriendRequest(String name) {
    return '$name vous a envoyé une demande d\'ami';
  }

  @override
  String sentGroupJoinRequest(String name, String groupName) {
    return '$name souhaite rejoindre $groupName';
  }

  @override
  String likedYourReading(String name, String bookTitle) {
    return '$name a aimé votre lecture de $bookTitle';
  }

  @override
  String commentedYourReading(String name, String bookTitle) {
    return '$name a commenté votre lecture de $bookTitle';
  }

  @override
  String get prizeSelections => 'Sélections LexDay';

  @override
  String get prizeSelectionsSubtitle => 'Prix littéraires officiels';

  @override
  String get officialLexDay => 'Officielle LexDay';

  @override
  String get bookSummary => 'Résumé du livre';

  @override
  String get noDescriptionAvailable => 'Aucun résumé disponible pour ce livre.';

  @override
  String get buyOnAmazon => 'Acheter sur Amazon';

  @override
  String get requestToJoin => 'Demander à rejoindre';

  @override
  String get joinRequestSent => 'Demande envoyée !';

  @override
  String get joinRequestPending => 'Demande en attente…';

  @override
  String get joinRequestCancelled => 'Demande annulée';

  @override
  String joinRequestAccepted(String name) {
    return '$name a été accepté(e) dans le club';
  }

  @override
  String joinRequestRejected(String name) {
    return 'Demande de $name refusée';
  }

  @override
  String pendingJoinRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes en attente',
      one: '1 demande en attente',
    );
    return '$_temp0';
  }

  @override
  String get reject => 'Refuser';

  @override
  String get readingForLabel => 'JE LIS POUR';

  @override
  String get readingForJustMe => 'Moi';

  @override
  String get readingForDaughter => 'Ma fille';

  @override
  String get readingForSon => 'Mon fils';

  @override
  String get readingForFriend => 'Un(e) ami(e)';

  @override
  String get readingForGrandmother => 'Ma grand-mère';

  @override
  String get readingForGrandfather => 'Mon grand-père';

  @override
  String get readingForPartner => 'Mon/Ma partenaire';

  @override
  String get readingForFather => 'Mon père';

  @override
  String get readingForMother => 'Ma mère';

  @override
  String get readingForOther => 'Autre';

  @override
  String readingForDisplay(String person) {
    return 'Lu pour $person';
  }

  @override
  String get readingForStatsTitle => 'Lectures partagées';

  @override
  String get readingForStatsSubtitle => 'Temps passé à lire pour vos proches';

  @override
  String readingForNoStats(String person) {
    return 'Vous n\'\'avez pas encore de session de lecture pour $person';
  }

  @override
  String readingForSessions(int count) {
    return '$count sessions';
  }

  @override
  String readingForMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String readingForPages(int pages) {
    return '$pages pages';
  }

  @override
  String get refreshCovers => 'Actualiser les couvertures';

  @override
  String get refreshingCovers => 'Actualisation en cours…';

  @override
  String coversRefreshed(int count) {
    return '$count couverture(s) mise(s) à jour';
  }

  @override
  String get coversUpToDate => 'Toutes les couvertures sont déjà à jour';

  @override
  String get friendsLabel => 'Amis';

  @override
  String get kindleLoginTitle => 'Connexion Kindle';

  @override
  String get kindleTrustBanner =>
      'Connexion directe à Amazon. Tes identifiants ne transitent jamais par LexDay.';

  @override
  String kindleBooksFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'livres trouvés',
      one: 'livre trouvé',
    );
    return '$_temp0';
  }

  @override
  String get kindleStepLibrary => 'Livres';

  @override
  String get kindleStepInsights => 'Stats';

  @override
  String get kindleStepImport => 'Import';

  @override
  String get kindlePhaseLoginTitle => 'Connecte-toi à Amazon';

  @override
  String get kindlePhaseLoginSubtitle =>
      'Tes identifiants restent sur Amazon,\nnous n\'y avons jamais accès.';

  @override
  String get kindlePhaseConnectingTitle => 'Connexion réussie !';

  @override
  String get kindlePhaseConnectingSubtitle =>
      'Redirection vers ta bibliothèque…';

  @override
  String get kindlePhaseLibraryTitle => 'Récupération de tes livres…';

  @override
  String get kindlePhaseLibrarySubtitle =>
      'On parcourt ta bibliothèque Kindle.';

  @override
  String get kindlePhaseInsightsTitle => 'Analyse de tes habitudes…';

  @override
  String get kindlePhaseInsightsSubtitle =>
      'On récupère tes statistiques de lecture.';

  @override
  String get kindlePhaseImportingTitle => 'Import en cours…';

  @override
  String get kindlePhaseImportingSubtitle =>
      'Tes livres arrivent dans ta bibliothèque LexDay.';

  @override
  String get kindlePhaseDoneTitle => 'C\'est tout bon !';

  @override
  String get kindlePhaseDoneSubtitle =>
      'Ta bibliothèque Kindle est synchronisée.';

  @override
  String get kindleOnboardingTitle => 'Connecte ton Kindle';

  @override
  String get kindleOnboardingSubtitle =>
      'Importe automatiquement ta bibliothèque Kindle.\nTes identifiants restent sur Amazon,\nnous n\'y avons jamais accès.';

  @override
  String get kindleOnboardingButton => 'Connecter mon Kindle';

  @override
  String get kindleOnboardingSkip => 'Passer cette étape';

  @override
  String get kindlePhaseErrorTitle => 'La synchronisation a pris trop de temps';

  @override
  String get kindlePhaseErrorSubtitle =>
      'Amazon n\'a pas répondu à temps.\nTu peux réessayer, ça prend généralement quelques secondes.';

  @override
  String get kindleRetryButton => 'Réessayer';

  @override
  String get premiumFeature => 'Fonctionnalité Premium';

  @override
  String get unlockFeatureWith => 'Débloquer avec Premium';

  @override
  String get premiumUpsellCta => 'Découvrir Premium';

  @override
  String get billingIssueTitle => 'Problème de paiement';

  @override
  String get billingIssueSubtitle =>
      'Vérifie ton moyen de paiement pour continuer';

  @override
  String savingsPercent(int percent) {
    return 'Économisez $percent%';
  }

  @override
  String get trialBadge => '7 jours gratuits';

  @override
  String get perMonth => '/mois';

  @override
  String thenPerYear(String price) {
    return 'puis $price/an';
  }

  @override
  String get noCommitment => 'Sans engagement';

  @override
  String get recommended => '✦ Recommandé';

  @override
  String get freeIncludedSessions => 'Sessions illimitées';

  @override
  String get freeIncludedLibrary => 'Bibliothèque illimitée';

  @override
  String get freeIncludedFeed => 'Feed social';

  @override
  String get freeIncludedGoals => 'Objectifs & badges de base';

  @override
  String get freeIncludedWrapped => 'Wrapped mensuel & annuel';

  @override
  String get freeIncludedWidget => 'Widget iOS';

  @override
  String get fabTooltip => 'Démarrer une lecture';

  @override
  String get shareMySession => 'Partager ma session';

  @override
  String get saveImage => 'Enregistrer l\'image';

  @override
  String get imageSaved => 'Image enregistrée';
}
