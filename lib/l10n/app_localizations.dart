import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @navFeed.
  ///
  /// In fr, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Biblio'**
  String get navLibrary;

  /// No description provided for @navClub.
  ///
  /// In fr, this message translates to:
  /// **'Club'**
  String get navClub;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Mon espace'**
  String get navProfile;

  /// No description provided for @kindleSyncedAutomatically.
  ///
  /// In fr, this message translates to:
  /// **'Kindle synchronisé automatiquement'**
  String get kindleSyncedAutomatically;

  /// No description provided for @enterEmailToReset.
  ///
  /// In fr, this message translates to:
  /// **'Entre ton email pour réinitialiser'**
  String get enterEmailToReset;

  /// No description provided for @emailSentCheckInbox.
  ///
  /// In fr, this message translates to:
  /// **'Email envoyé, vérifie ta boîte.'**
  String get emailSentCheckInbox;

  /// No description provided for @errorSendingEmail.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'envoi de l\'email'**
  String get errorSendingEmail;

  /// No description provided for @tooManyAttemptsRetryIn.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessaie dans {seconds}s'**
  String tooManyAttemptsRetryIn(int seconds);

  /// No description provided for @emailAndPasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Email et mot de passe requis'**
  String get emailAndPasswordRequired;

  /// No description provided for @loginFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible'**
  String get loginFailed;

  /// No description provided for @unknownError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur inconnue'**
  String get unknownError;

  /// No description provided for @errorSignInApple.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion avec Apple'**
  String get errorSignInApple;

  /// No description provided for @errorSignInGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la connexion avec Google'**
  String get errorSignInGoogle;

  /// No description provided for @welcomeBack.
  ///
  /// In fr, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @reader.
  ///
  /// In fr, this message translates to:
  /// **'reader.'**
  String get reader;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'EMAIL'**
  String get email;

  /// No description provided for @emailLower.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get emailLower;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'PASSWORD'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @continueReading.
  ///
  /// In fr, this message translates to:
  /// **'Continue Reading'**
  String get continueReading;

  /// No description provided for @or.
  ///
  /// In fr, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @newToLexDay.
  ///
  /// In fr, this message translates to:
  /// **'New to LexDay? '**
  String get newToLexDay;

  /// No description provided for @createAnAccount.
  ///
  /// In fr, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @emailAlreadyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Email déjà utilisé'**
  String get emailAlreadyUsed;

  /// No description provided for @emailAlreadyUsedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse email est déjà associée à un compte existant. Souhaitez-vous réinitialiser votre mot de passe ?'**
  String get emailAlreadyUsedMessage;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get reset;

  /// No description provided for @resetEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'Email de réinitialisation envoyé. Vérifie ta boîte mail.'**
  String get resetEmailSent;

  /// No description provided for @passwordMin8Chars.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 8 caractères'**
  String get passwordMin8Chars;

  /// No description provided for @passwordRequirements.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir majuscule, minuscule et chiffre'**
  String get passwordRequirements;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez accepter les conditions d\'utilisation'**
  String get mustAcceptTerms;

  /// No description provided for @accountCreatedCheckEmail.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé, vérifie tes emails.'**
  String get accountCreatedCheckEmail;

  /// No description provided for @createAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccountTitle;

  /// No description provided for @joinLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins LexDay'**
  String get joinLexDay;

  /// No description provided for @enterInfoToStart.
  ///
  /// In fr, this message translates to:
  /// **'Entre tes informations pour commencer à lire'**
  String get enterInfoToStart;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @yourName.
  ///
  /// In fr, this message translates to:
  /// **'Ton nom'**
  String get yourName;

  /// No description provided for @yourEmail.
  ///
  /// In fr, this message translates to:
  /// **'ton.email@mail.com'**
  String get yourEmail;

  /// No description provided for @passwordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// No description provided for @createAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ? Se connecter'**
  String get alreadyHaveAccount;

  /// No description provided for @legalNotices.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get legalNotices;

  /// No description provided for @emailSent.
  ///
  /// In fr, this message translates to:
  /// **'Email envoyé'**
  String get emailSent;

  /// No description provided for @checkYourEmail.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ta boîte mail'**
  String get checkYourEmail;

  /// No description provided for @confirmEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'Nous t\'avons envoyé un lien pour confirmer ton adresse email.'**
  String get confirmEmailSent;

  /// No description provided for @iConfirmedMyEmail.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai confirmé mon email'**
  String get iConfirmedMyEmail;

  /// No description provided for @suggestionsForYou.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions pour toi'**
  String get suggestionsForYou;

  /// No description provided for @bookAddedToLibrary.
  ///
  /// In fr, this message translates to:
  /// **'{title} ajouté à votre bibliothèque'**
  String bookAddedToLibrary(String title);

  /// No description provided for @errorAddingBook.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'ajout du livre'**
  String get errorAddingBook;

  /// No description provided for @recentSessions.
  ///
  /// In fr, this message translates to:
  /// **'Sessions récentes'**
  String get recentSessions;

  /// No description provided for @recentBadges.
  ///
  /// In fr, this message translates to:
  /// **'Badges récents'**
  String get recentBadges;

  /// No description provided for @friendsActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité de tes amis'**
  String get friendsActivity;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir'**
  String get refresh;

  /// No description provided for @friendsNotReadToday.
  ///
  /// In fr, this message translates to:
  /// **'Tes amis n\'ont pas encore lu aujourd\'hui'**
  String get friendsNotReadToday;

  /// No description provided for @noActivityYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'activité'**
  String get noActivityYet;

  /// No description provided for @addFriendsToSeeActivity.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des amis pour voir leurs lectures!'**
  String get addFriendsToSeeActivity;

  /// No description provided for @shareInviteText.
  ///
  /// In fr, this message translates to:
  /// **'📖 Rejoins-moi sur LexDay !\n\nTu lis quoi en ce moment ? 👀\nlexday.app'**
  String get shareInviteText;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {message}'**
  String errorGeneric(String message);

  /// No description provided for @myLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Ma Bibliothèque'**
  String get myLibrary;

  /// No description provided for @refreshTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rafraîchir'**
  String get refreshTooltip;

  /// No description provided for @searchBook.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un livre...'**
  String get searchBook;

  /// No description provided for @statusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get statusLabel;

  /// No description provided for @genreLabel.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get genreLabel;

  /// No description provided for @noBooksInLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre dans votre bibliothèque'**
  String get noBooksInLibrary;

  /// No description provided for @scanOrSyncBooks.
  ///
  /// In fr, this message translates to:
  /// **'Scannez une couverture ou synchronisez vos livres Kindle'**
  String get scanOrSyncBooks;

  /// No description provided for @authorFoundForBooks.
  ///
  /// In fr, this message translates to:
  /// **'Auteur trouvé pour {count} livre{count, plural, =1{} other{s}}'**
  String authorFoundForBooks(int count);

  /// No description provided for @noAuthorFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun auteur trouvé'**
  String get noAuthorFound;

  /// No description provided for @errorSearchingAuthors.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la recherche des auteurs'**
  String get errorSearchingAuthors;

  /// No description provided for @searchingInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Recherche en cours...'**
  String get searchingInProgress;

  /// No description provided for @searchMissingAuthors.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher les auteurs manquants'**
  String get searchMissingAuthors;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @profileSection.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileSection;

  /// No description provided for @editName.
  ///
  /// In fr, this message translates to:
  /// **'✏️ Modifier le nom'**
  String get editName;

  /// No description provided for @uploadingPhoto.
  ///
  /// In fr, this message translates to:
  /// **'📸 Upload en cours...'**
  String get uploadingPhoto;

  /// No description provided for @changeProfilePicture.
  ///
  /// In fr, this message translates to:
  /// **'📸 Changer la photo de profil'**
  String get changeProfilePicture;

  /// No description provided for @subscriptionSection.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement'**
  String get subscriptionSection;

  /// No description provided for @upgradeToPremium.
  ///
  /// In fr, this message translates to:
  /// **'Passer à Premium'**
  String get upgradeToPremium;

  /// No description provided for @freeTrial.
  ///
  /// In fr, this message translates to:
  /// **'Essai gratuit'**
  String get freeTrial;

  /// No description provided for @freeTrialUntil.
  ///
  /// In fr, this message translates to:
  /// **'Essai gratuit (jusqu\'au {date})'**
  String freeTrialUntil(String date);

  /// No description provided for @premiumActive.
  ///
  /// In fr, this message translates to:
  /// **'Premium actif'**
  String get premiumActive;

  /// No description provided for @premiumActiveUntil.
  ///
  /// In fr, this message translates to:
  /// **'Premium actif (jusqu\'au {date})'**
  String premiumActiveUntil(String date);

  /// No description provided for @privacySection.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get privacySection;

  /// No description provided for @privateProfile.
  ///
  /// In fr, this message translates to:
  /// **'🔒 Profil privé'**
  String get privateProfile;

  /// No description provided for @statsHidden.
  ///
  /// In fr, this message translates to:
  /// **'Tes statistiques sont cachées'**
  String get statsHidden;

  /// No description provided for @statsPublic.
  ///
  /// In fr, this message translates to:
  /// **'Tes statistiques sont publiques'**
  String get statsPublic;

  /// No description provided for @privateProfileInfoOn.
  ///
  /// In fr, this message translates to:
  /// **'Les autres utilisateurs ne verront que ton nom et ta photo de profil.'**
  String get privateProfileInfoOn;

  /// No description provided for @privateProfileInfoOff.
  ///
  /// In fr, this message translates to:
  /// **'Les autres utilisateurs pourront voir tes badges, livres, flow et statistiques.'**
  String get privateProfileInfoOff;

  /// No description provided for @hideReadingHours.
  ///
  /// In fr, this message translates to:
  /// **'⏱️ Masquer les heures de lecture'**
  String get hideReadingHours;

  /// No description provided for @readingHoursHidden.
  ///
  /// In fr, this message translates to:
  /// **'Tes heures de lecture sont cachées'**
  String get readingHoursHidden;

  /// No description provided for @readingHoursVisible.
  ///
  /// In fr, this message translates to:
  /// **'Tes heures de lecture sont visibles'**
  String get readingHoursVisible;

  /// No description provided for @readingHoursInfo.
  ///
  /// In fr, this message translates to:
  /// **'Les autres utilisateurs ne verront pas ton temps de lecture total.'**
  String get readingHoursInfo;

  /// No description provided for @profilePrivateEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Profil privé activé. Seuls tes amis verront tes statistiques.'**
  String get profilePrivateEnabled;

  /// No description provided for @profilePublicEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Profil public activé. Tout le monde peut voir tes statistiques.'**
  String get profilePublicEnabled;

  /// No description provided for @readingHoursHiddenSnack.
  ///
  /// In fr, this message translates to:
  /// **'Heures de lecture masquées.'**
  String get readingHoursHiddenSnack;

  /// No description provided for @readingHoursVisibleSnack.
  ///
  /// In fr, this message translates to:
  /// **'Heures de lecture visibles.'**
  String get readingHoursVisibleSnack;

  /// No description provided for @readingSection.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get readingSection;

  /// No description provided for @editReadingGoal.
  ///
  /// In fr, this message translates to:
  /// **'🎯 Modifier l\'objectif de lecture'**
  String get editReadingGoal;

  /// No description provided for @flowNotifications.
  ///
  /// In fr, this message translates to:
  /// **'🔔 Notifications de flow'**
  String get flowNotifications;

  /// No description provided for @kindleSection.
  ///
  /// In fr, this message translates to:
  /// **'Kindle'**
  String get kindleSection;

  /// No description provided for @resyncKindle.
  ///
  /// In fr, this message translates to:
  /// **'📚 Resynchroniser Kindle'**
  String get resyncKindle;

  /// No description provided for @connectKindle.
  ///
  /// In fr, this message translates to:
  /// **'📚 Connecter Kindle'**
  String get connectKindle;

  /// No description provided for @lastSync.
  ///
  /// In fr, this message translates to:
  /// **'✅ Dernière sync: {date}'**
  String lastSync(String date);

  /// No description provided for @autoSync.
  ///
  /// In fr, this message translates to:
  /// **'Sync automatique'**
  String get autoSync;

  /// No description provided for @kindleAutoSyncDescription.
  ///
  /// In fr, this message translates to:
  /// **'Synchronise tes livres Kindle à chaque ouverture'**
  String get kindleAutoSyncDescription;

  /// No description provided for @kindleSyncedSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Kindle synchronisé avec succès !'**
  String get kindleSyncedSuccess;

  /// No description provided for @notionSection.
  ///
  /// In fr, this message translates to:
  /// **'Notion'**
  String get notionSection;

  /// No description provided for @connectedTo.
  ///
  /// In fr, this message translates to:
  /// **'Connecté à {name}'**
  String connectedTo(String name);

  /// No description provided for @notionSheetsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Tes fiches de lecture peuvent être envoyées vers Notion'**
  String get notionSheetsDescription;

  /// No description provided for @reconnect.
  ///
  /// In fr, this message translates to:
  /// **'Reconnecter'**
  String get reconnect;

  /// No description provided for @disconnect.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get disconnect;

  /// No description provided for @connectNotion.
  ///
  /// In fr, this message translates to:
  /// **'📝 Connecter Notion'**
  String get connectNotion;

  /// No description provided for @notionSyncDescription.
  ///
  /// In fr, this message translates to:
  /// **'Synchronise tes fiches de lecture IA vers une base Notion'**
  String get notionSyncDescription;

  /// No description provided for @disconnectNotionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter Notion ?'**
  String get disconnectNotionTitle;

  /// No description provided for @disconnectNotionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tes fiches déjà synchronisées resteront dans Notion.'**
  String get disconnectNotionMessage;

  /// No description provided for @notionDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'Notion déconnecté'**
  String get notionDisconnected;

  /// No description provided for @appearanceSection.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearanceSection;

  /// No description provided for @lightTheme.
  ///
  /// In fr, this message translates to:
  /// **'🌞 Thème clair'**
  String get lightTheme;

  /// No description provided for @lightThemeActive.
  ///
  /// In fr, this message translates to:
  /// **'🌞 Thème clair (actif)'**
  String get lightThemeActive;

  /// No description provided for @darkTheme.
  ///
  /// In fr, this message translates to:
  /// **'🌙 Thème sombre'**
  String get darkTheme;

  /// No description provided for @darkThemeActive.
  ///
  /// In fr, this message translates to:
  /// **'🌙 Thème sombre (actif)'**
  String get darkThemeActive;

  /// No description provided for @systemTheme.
  ///
  /// In fr, this message translates to:
  /// **'📱 Automatique'**
  String get systemTheme;

  /// No description provided for @systemThemeActive.
  ///
  /// In fr, this message translates to:
  /// **'📱 Automatique (actif)'**
  String get systemThemeActive;

  /// No description provided for @languageSection.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageSection;

  /// No description provided for @frenchActive.
  ///
  /// In fr, this message translates to:
  /// **'🇫🇷 Français (actif)'**
  String get frenchActive;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'🇫🇷 Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'🇬🇧 English'**
  String get english;

  /// No description provided for @englishActive.
  ///
  /// In fr, this message translates to:
  /// **'🇬🇧 English (active)'**
  String get englishActive;

  /// No description provided for @spanish.
  ///
  /// In fr, this message translates to:
  /// **'🇪🇸 Español'**
  String get spanish;

  /// No description provided for @spanishActive.
  ///
  /// In fr, this message translates to:
  /// **'🇪🇸 Español (activo)'**
  String get spanishActive;

  /// No description provided for @accountSection.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get accountSection;

  /// No description provided for @manageConnections.
  ///
  /// In fr, this message translates to:
  /// **'🖥️ Gérer connexions & appareils'**
  String get manageConnections;

  /// No description provided for @legalSection.
  ///
  /// In fr, this message translates to:
  /// **'Légal'**
  String get legalSection;

  /// No description provided for @termsOfService.
  ///
  /// In fr, this message translates to:
  /// **'📜 Conditions d\'utilisation'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicy;

  /// No description provided for @legalNoticesItem.
  ///
  /// In fr, this message translates to:
  /// **'⚖️ Mentions légales'**
  String get legalNoticesItem;

  /// No description provided for @logoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get logoutTitle;

  /// No description provided for @logoutMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu vas être déconnecté. Continuer ?'**
  String get logoutMessage;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'❌ Se déconnecter'**
  String get logout;

  /// No description provided for @dangerZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone de danger'**
  String get dangerZone;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In fr, this message translates to:
  /// **'La suppression du compte est irréversible.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteMyAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ton compte ?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Toutes tes données (livres, sessions de lecture, badges, amis, groupes) seront définitivement supprimées.'**
  String get deleteAccountMessage;

  /// No description provided for @continueButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueButton;

  /// No description provided for @confirmDeletion.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get confirmDeletion;

  /// No description provided for @typeDeleteToConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer, tape SUPPRIMER ci-dessous :'**
  String get typeDeleteToConfirm;

  /// No description provided for @deleteKeyword.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteKeyword;

  /// No description provided for @deleteForever.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteForever;

  /// No description provided for @errorDeletingAccount.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression : {error}'**
  String errorDeletingAccount(String error);

  /// No description provided for @editNameTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le nom'**
  String get editNameTitle;

  /// No description provided for @displayName.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'affichage'**
  String get displayName;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @nameMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 2 caractères'**
  String get nameMinLength;

  /// No description provided for @nameMaxLength.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne doit pas dépasser 50 caractères'**
  String get nameMaxLength;

  /// No description provided for @nameUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Nom mis à jour!'**
  String get nameUpdated;

  /// No description provided for @takePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get chooseFromGallery;

  /// No description provided for @imageTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Image trop grande. Taille maximum: 5MB'**
  String get imageTooLarge;

  /// No description provided for @unsupportedFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format non supporté. Utilisez JPG, PNG ou WebP'**
  String get unsupportedFormat;

  /// No description provided for @notConnected.
  ///
  /// In fr, this message translates to:
  /// **'Non connecté'**
  String get notConnected;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In fr, this message translates to:
  /// **'✅ Photo de profil mise à jour!'**
  String get profilePictureUpdated;

  /// No description provided for @timeAgoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {minutes} min'**
  String timeAgoMinutes(int minutes);

  /// No description provided for @timeAgoHours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {hours}h'**
  String timeAgoHours(int hours);

  /// No description provided for @timeAgoDays.
  ///
  /// In fr, this message translates to:
  /// **'il y a {days}j'**
  String timeAgoDays(int days);

  /// No description provided for @libraryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Votre bibliothèque est vide'**
  String get libraryEmpty;

  /// No description provided for @sessionAbandoned.
  ///
  /// In fr, this message translates to:
  /// **'Session abandonnée'**
  String get sessionAbandoned;

  /// No description provided for @muse.
  ///
  /// In fr, this message translates to:
  /// **'💡 Muse'**
  String get muse;

  /// No description provided for @newBook.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau livre'**
  String get newBook;

  /// No description provided for @myLibraryFab.
  ///
  /// In fr, this message translates to:
  /// **'Ma bibliothèque'**
  String get myLibraryFab;

  /// No description provided for @searchEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get searchEllipsis;

  /// No description provided for @noBookFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre trouvé'**
  String get noBookFound;

  /// No description provided for @abandonSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner la session'**
  String get abandonSessionTitle;

  /// No description provided for @abandonSessionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment abandonner cette session de lecture ?'**
  String get abandonSessionMessage;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @leaveSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la session'**
  String get leaveSessionTitle;

  /// No description provided for @leaveSessionMessage.
  ///
  /// In fr, this message translates to:
  /// **'La session reste active. Vous pourrez la terminer plus tard.'**
  String get leaveSessionMessage;

  /// No description provided for @stay.
  ///
  /// In fr, this message translates to:
  /// **'Rester'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get leave;

  /// No description provided for @sessionInProgress.
  ///
  /// In fr, this message translates to:
  /// **'SESSION EN COURS'**
  String get sessionInProgress;

  /// No description provided for @cancelSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la session'**
  String get cancelSessionTitle;

  /// No description provided for @cancelSessionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir annuler cette session de lecture ?'**
  String get cancelSessionMessage;

  /// No description provided for @errorCapture.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la capture: {error}'**
  String errorCapture(String error);

  /// No description provided for @errorGoogleBooks.
  ///
  /// In fr, this message translates to:
  /// **'Erreur recherche Google Books'**
  String get errorGoogleBooks;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get termsOfServiceTitle;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get privacyPolicyTitle;

  /// No description provided for @legalNoticesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get legalNoticesTitle;

  /// No description provided for @iAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les conditions'**
  String get iAcceptTerms;

  /// No description provided for @sessionDuration.
  ///
  /// In fr, this message translates to:
  /// **'DURÉE DE SESSION'**
  String get sessionDuration;

  /// No description provided for @startPage.
  ///
  /// In fr, this message translates to:
  /// **'Page de départ'**
  String get startPage;

  /// No description provided for @streakLabel.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get streakLabel;

  /// No description provided for @streakDays.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours'**
  String streakDays(int days);

  /// No description provided for @endSessionSlide.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la session'**
  String get endSessionSlide;

  /// No description provided for @abandonButton.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get abandonButton;

  /// No description provided for @newAnnotation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle annotation'**
  String get newAnnotation;

  /// No description provided for @annotationText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get annotationText;

  /// No description provided for @annotationPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get annotationPhoto;

  /// No description provided for @annotationVoice.
  ///
  /// In fr, this message translates to:
  /// **'Vocal'**
  String get annotationVoice;

  /// No description provided for @retakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la photo'**
  String get retakePhoto;

  /// No description provided for @extractingText.
  ///
  /// In fr, this message translates to:
  /// **'Extraction du texte...'**
  String get extractingText;

  /// No description provided for @micPermissionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Permission microphone requise'**
  String get micPermissionRequired;

  /// No description provided for @tapToRecord.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour enregistrer'**
  String get tapToRecord;

  /// No description provided for @recordingInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement en cours...'**
  String get recordingInProgress;

  /// No description provided for @retakeRecording.
  ///
  /// In fr, this message translates to:
  /// **'Refaire'**
  String get retakeRecording;

  /// No description provided for @transcriptionInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Transcription en cours...'**
  String get transcriptionInProgress;

  /// No description provided for @hintExtractedText.
  ///
  /// In fr, this message translates to:
  /// **'Texte extrait (modifiable)...'**
  String get hintExtractedText;

  /// No description provided for @hintTranscription.
  ///
  /// In fr, this message translates to:
  /// **'Transcription (modifiable)...'**
  String get hintTranscription;

  /// No description provided for @hintAnnotation.
  ///
  /// In fr, this message translates to:
  /// **'Notez votre pensée, une citation...'**
  String get hintAnnotation;

  /// No description provided for @voiceAnnotationSaved.
  ///
  /// In fr, this message translates to:
  /// **'Annotation vocale sauvegardée !'**
  String get voiceAnnotationSaved;

  /// No description provided for @annotationSaved.
  ///
  /// In fr, this message translates to:
  /// **'Annotation sauvegardée !'**
  String get annotationSaved;

  /// No description provided for @transcribing.
  ///
  /// In fr, this message translates to:
  /// **'Transcription...'**
  String get transcribing;

  /// No description provided for @pageHint.
  ///
  /// In fr, this message translates to:
  /// **'Page'**
  String get pageHint;

  /// No description provided for @errorSelection.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la sélection: {error}'**
  String errorSelection(String error);

  /// No description provided for @pageNotDetected.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de page non détecté. Saisissez-le manuellement.'**
  String get pageNotDetected;

  /// No description provided for @pageNotDetectedManual.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de page non détecté. Vous pouvez le saisir manuellement ci-dessous.'**
  String get pageNotDetectedManual;

  /// No description provided for @endPageBeforeStartDetailed.
  ///
  /// In fr, this message translates to:
  /// **'La page de fin ({endPage}) ne peut pas être avant la page de début ({startPage}).'**
  String endPageBeforeStartDetailed(int endPage, int startPage);

  /// No description provided for @ocrError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur OCR: {error}'**
  String ocrError(String error);

  /// No description provided for @invalidPageNumber.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un numéro de page valide.'**
  String get invalidPageNumber;

  /// No description provided for @captureOrEnterPage.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez capturer une photo ou saisir un numéro de page.'**
  String get captureOrEnterPage;

  /// No description provided for @endPageBeforeStart.
  ///
  /// In fr, this message translates to:
  /// **'La page de fin ne peut pas être avant la page de début.'**
  String get endPageBeforeStart;

  /// No description provided for @finishBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le livre'**
  String get finishBookTitle;

  /// No description provided for @finishBookConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Félicitations! Avez-vous terminé ce livre ?'**
  String get finishBookConfirm;

  /// No description provided for @yesFinished.
  ///
  /// In fr, this message translates to:
  /// **'Oui, terminé!'**
  String get yesFinished;

  /// No description provided for @endReading.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la lecture'**
  String get endReading;

  /// No description provided for @currentSession.
  ///
  /// In fr, this message translates to:
  /// **'Session en cours'**
  String get currentSession;

  /// No description provided for @startedAtPage.
  ///
  /// In fr, this message translates to:
  /// **'Commencée à la page {page}'**
  String startedAtPage(int page);

  /// No description provided for @durationValue.
  ///
  /// In fr, this message translates to:
  /// **'Durée: {duration}'**
  String durationValue(String duration);

  /// No description provided for @instructions.
  ///
  /// In fr, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @instructionEndPhoto.
  ///
  /// In fr, this message translates to:
  /// **'1. Photographiez votre dernière page lue'**
  String get instructionEndPhoto;

  /// No description provided for @instructionEndVisible.
  ///
  /// In fr, this message translates to:
  /// **'2. Assurez-vous que le numéro est visible'**
  String get instructionEndVisible;

  /// No description provided for @instructionEndValidate.
  ///
  /// In fr, this message translates to:
  /// **'3. Validez pour enregistrer votre progression'**
  String get instructionEndValidate;

  /// No description provided for @instructionStartPhoto.
  ///
  /// In fr, this message translates to:
  /// **'1. Photographiez la page où vous commencez'**
  String get instructionStartPhoto;

  /// No description provided for @instructionStartVisible.
  ///
  /// In fr, this message translates to:
  /// **'2. Assurez-vous que le numéro de page est visible'**
  String get instructionStartVisible;

  /// No description provided for @instructionStartOcr.
  ///
  /// In fr, this message translates to:
  /// **'3. L\'OCR détectera automatiquement le numéro'**
  String get instructionStartOcr;

  /// No description provided for @takePhotoBtn.
  ///
  /// In fr, this message translates to:
  /// **'Prendre Photo'**
  String get takePhotoBtn;

  /// No description provided for @galleryBtn.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get galleryBtn;

  /// No description provided for @analyzing.
  ///
  /// In fr, this message translates to:
  /// **'Analyse en cours...'**
  String get analyzing;

  /// No description provided for @photoCaptured.
  ///
  /// In fr, this message translates to:
  /// **'Photo capturée:'**
  String get photoCaptured;

  /// No description provided for @pageCorrected.
  ///
  /// In fr, this message translates to:
  /// **'Page corrigée:'**
  String get pageCorrected;

  /// No description provided for @pageDetected.
  ///
  /// In fr, this message translates to:
  /// **'Page détectée:'**
  String get pageDetected;

  /// No description provided for @pagesReadCount.
  ///
  /// In fr, this message translates to:
  /// **'Pages lues: {count}'**
  String pagesReadCount(int count);

  /// No description provided for @correctNumber.
  ///
  /// In fr, this message translates to:
  /// **'Corriger le numéro'**
  String get correctNumber;

  /// No description provided for @pageNumberLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de page'**
  String get pageNumberLabel;

  /// No description provided for @startPagePrefix.
  ///
  /// In fr, this message translates to:
  /// **'Page de début: {page}'**
  String startPagePrefix(int page);

  /// No description provided for @validate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get validate;

  /// No description provided for @orEnterManually.
  ///
  /// In fr, this message translates to:
  /// **'Ou saisissez le numéro directement:'**
  String get orEnterManually;

  /// No description provided for @startReadingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer une lecture'**
  String get startReadingTitle;

  /// No description provided for @sessionAlreadyActive.
  ///
  /// In fr, this message translates to:
  /// **'Une session est déjà en cours'**
  String get sessionAlreadyActive;

  /// No description provided for @resumeSession.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre la session'**
  String get resumeSession;

  /// No description provided for @startReadingSession.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer la session de lecture'**
  String get startReadingSession;

  /// No description provided for @congratulations.
  ///
  /// In fr, this message translates to:
  /// **'Félicitations!'**
  String get congratulations;

  /// No description provided for @bookFinishedExcl.
  ///
  /// In fr, this message translates to:
  /// **'Livre terminé!'**
  String get bookFinishedExcl;

  /// No description provided for @continueExcl.
  ///
  /// In fr, this message translates to:
  /// **'Continuer!'**
  String get continueExcl;

  /// No description provided for @flowBadgeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Badge Flow!'**
  String get flowBadgeTitle;

  /// No description provided for @consecutiveDays.
  ///
  /// In fr, this message translates to:
  /// **'{days} jour{days, plural, =1{} other{s}} consécutif{days, plural, =1{} other{s}}!'**
  String consecutiveDays(int days);

  /// No description provided for @museBookFinished.
  ///
  /// In fr, this message translates to:
  /// **'Bravo pour {title} ! Envie que Muse te conseille ta prochaine lecture ?'**
  String museBookFinished(String title);

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// No description provided for @chatWithMuse.
  ///
  /// In fr, this message translates to:
  /// **'Discuter avec Muse'**
  String get chatWithMuse;

  /// No description provided for @defaultUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get defaultUser;

  /// No description provided for @mySessions.
  ///
  /// In fr, this message translates to:
  /// **'Mes Sessions'**
  String get mySessions;

  /// No description provided for @myStatistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get myStatistics;

  /// No description provided for @myLists.
  ///
  /// In fr, this message translates to:
  /// **'Mes Listes'**
  String get myLists;

  /// No description provided for @statistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statistics;

  /// No description provided for @readingStatistics.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques de lecture'**
  String get readingStatistics;

  /// No description provided for @featureComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité à venir'**
  String get featureComingSoon;

  /// No description provided for @cannotAddBook.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce livre'**
  String get cannotAddBook;

  /// No description provided for @titleAuthorPagesRequired.
  ///
  /// In fr, this message translates to:
  /// **'Titre, auteur et pages requis'**
  String get titleAuthorPagesRequired;

  /// No description provided for @bookAdded.
  ///
  /// In fr, this message translates to:
  /// **'Livre ajouté'**
  String get bookAdded;

  /// No description provided for @errorAdding.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'ajout'**
  String get errorAdding;

  /// No description provided for @addBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un livre'**
  String get addBookTitle;

  /// No description provided for @googleBooksSearchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche Google Books'**
  String get googleBooksSearchTitle;

  /// No description provided for @titleAuthorIsbn.
  ///
  /// In fr, this message translates to:
  /// **'Titre, auteur ou ISBN'**
  String get titleAuthorIsbn;

  /// No description provided for @noTitleDefault.
  ///
  /// In fr, this message translates to:
  /// **'Sans titre'**
  String get noTitleDefault;

  /// No description provided for @addButton.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addButton;

  /// No description provided for @manualAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajout manuel'**
  String get manualAdd;

  /// No description provided for @titleHint.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get titleHint;

  /// No description provided for @authorHint.
  ///
  /// In fr, this message translates to:
  /// **'Auteur'**
  String get authorHint;

  /// No description provided for @totalPages.
  ///
  /// In fr, this message translates to:
  /// **'Pages totales'**
  String get totalPages;

  /// No description provided for @activeSessionDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session en cours'**
  String get activeSessionDialogTitle;

  /// No description provided for @activeSessionDialogMessage.
  ///
  /// In fr, this message translates to:
  /// **'Une session de lecture est déjà en cours pour ce livre.'**
  String get activeSessionDialogMessage;

  /// No description provided for @pageAtNumber.
  ///
  /// In fr, this message translates to:
  /// **'Page {page}'**
  String pageAtNumber(int page);

  /// No description provided for @whatDoYouWant.
  ///
  /// In fr, this message translates to:
  /// **'Que voulez-vous faire ?'**
  String get whatDoYouWant;

  /// No description provided for @resume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get resume;

  /// No description provided for @sessionCompleted.
  ///
  /// In fr, this message translates to:
  /// **'SESSION TERMINÉE'**
  String get sessionCompleted;

  /// No description provided for @sessionCompletedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session terminée !'**
  String get sessionCompletedTitle;

  /// No description provided for @myReadingDefault.
  ///
  /// In fr, this message translates to:
  /// **'Ma lecture'**
  String get myReadingDefault;

  /// No description provided for @durationStatLabel.
  ///
  /// In fr, this message translates to:
  /// **'durée'**
  String get durationStatLabel;

  /// No description provided for @pagesReadStatLabel.
  ///
  /// In fr, this message translates to:
  /// **'pages lues'**
  String get pagesReadStatLabel;

  /// No description provided for @streakStatLabel.
  ///
  /// In fr, this message translates to:
  /// **'série'**
  String get streakStatLabel;

  /// No description provided for @streakDaysShort.
  ///
  /// In fr, this message translates to:
  /// **'{days} j.'**
  String streakDaysShort(int days);

  /// No description provided for @readingPace.
  ///
  /// In fr, this message translates to:
  /// **'Rythme de lecture'**
  String get readingPace;

  /// No description provided for @avgTimePerPage.
  ///
  /// In fr, this message translates to:
  /// **'Temps moyen par page'**
  String get avgTimePerPage;

  /// No description provided for @estimatedBookEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin estimée du livre'**
  String get estimatedBookEnd;

  /// No description provided for @vsYourAverage.
  ///
  /// In fr, this message translates to:
  /// **'vs. ta moyenne'**
  String get vsYourAverage;

  /// No description provided for @fasterPercent.
  ///
  /// In fr, this message translates to:
  /// **'+{percent}% plus rapide'**
  String fasterPercent(int percent);

  /// No description provided for @slowerPercent.
  ///
  /// In fr, this message translates to:
  /// **'{percent}% plus lent'**
  String slowerPercent(int percent);

  /// No description provided for @withinAverage.
  ///
  /// In fr, this message translates to:
  /// **'Dans ta moyenne'**
  String get withinAverage;

  /// No description provided for @sessionInsights.
  ///
  /// In fr, this message translates to:
  /// **'Insights de la session'**
  String get sessionInsights;

  /// No description provided for @viewFullReport.
  ///
  /// In fr, this message translates to:
  /// **'✨ Voir le bilan complet'**
  String get viewFullReport;

  /// No description provided for @paceAndTrends.
  ///
  /// In fr, this message translates to:
  /// **'Rythme, tendances, estimation de fin et plus'**
  String get paceAndTrends;

  /// No description provided for @tryPremium.
  ///
  /// In fr, this message translates to:
  /// **'Essayer'**
  String get tryPremium;

  /// No description provided for @shareSession.
  ///
  /// In fr, this message translates to:
  /// **'Partager la session'**
  String get shareSession;

  /// No description provided for @hideSession.
  ///
  /// In fr, this message translates to:
  /// **'Masquer cette session'**
  String get hideSession;

  /// No description provided for @sessionHiddenFromRankings.
  ///
  /// In fr, this message translates to:
  /// **'Session masquée des classements'**
  String get sessionHiddenFromRankings;

  /// No description provided for @errorHidingSession.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du masquage'**
  String get errorHidingSession;

  /// No description provided for @skip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skip;

  /// No description provided for @nPages.
  ///
  /// In fr, this message translates to:
  /// **'{count} pages'**
  String nPages(int count);

  /// No description provided for @bookCompletedHeader.
  ///
  /// In fr, this message translates to:
  /// **'LIVRE TERMINÉ'**
  String get bookCompletedHeader;

  /// No description provided for @bookCompletedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livre terminé !'**
  String get bookCompletedTitle;

  /// No description provided for @congratsFinished.
  ///
  /// In fr, this message translates to:
  /// **'Félicitations, tu as terminé'**
  String get congratsFinished;

  /// No description provided for @completed.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get completed;

  /// No description provided for @ofReading.
  ///
  /// In fr, this message translates to:
  /// **'de lecture'**
  String get ofReading;

  /// No description provided for @sessions.
  ///
  /// In fr, this message translates to:
  /// **'sessions'**
  String get sessions;

  /// No description provided for @readingDaysCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} jours de lecture'**
  String readingDaysCount(int count);

  /// No description provided for @bookReport.
  ///
  /// In fr, this message translates to:
  /// **'Bilan du livre'**
  String get bookReport;

  /// No description provided for @avgPace.
  ///
  /// In fr, this message translates to:
  /// **'Rythme moyen'**
  String get avgPace;

  /// No description provided for @preferredSlot.
  ///
  /// In fr, this message translates to:
  /// **'Créneau préféré'**
  String get preferredSlot;

  /// No description provided for @bestSession.
  ///
  /// In fr, this message translates to:
  /// **'Meilleure session'**
  String get bestSession;

  /// No description provided for @readingRegularity.
  ///
  /// In fr, this message translates to:
  /// **'Régularité de lecture'**
  String get readingRegularity;

  /// No description provided for @morningSlot.
  ///
  /// In fr, this message translates to:
  /// **'Matin (6h–12h)'**
  String get morningSlot;

  /// No description provided for @afternoonSlot.
  ///
  /// In fr, this message translates to:
  /// **'Après-midi (12h–18h)'**
  String get afternoonSlot;

  /// No description provided for @eveningSlot.
  ///
  /// In fr, this message translates to:
  /// **'Soir (18h–22h)'**
  String get eveningSlot;

  /// No description provided for @nightSlot.
  ///
  /// In fr, this message translates to:
  /// **'Nuit (22h–6h)'**
  String get nightSlot;

  /// No description provided for @unknownSlot.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknownSlot;

  /// No description provided for @pagesInDuration.
  ///
  /// In fr, this message translates to:
  /// **'{pages} pages en {duration}'**
  String pagesInDuration(int pages, String duration);

  /// No description provided for @daysPerWeek.
  ///
  /// In fr, this message translates to:
  /// **'{count} j/sem'**
  String daysPerWeek(String count);

  /// No description provided for @unlockedBadges.
  ///
  /// In fr, this message translates to:
  /// **'Badges débloqués'**
  String get unlockedBadges;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @backToHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get backToHome;

  /// No description provided for @paceAndSlots.
  ///
  /// In fr, this message translates to:
  /// **'Rythme, créneaux, régularité et plus'**
  String get paceAndSlots;

  /// No description provided for @clubSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'communauté'**
  String get clubSubtitle;

  /// No description provided for @readingClubs.
  ///
  /// In fr, this message translates to:
  /// **'Clubs de lecture'**
  String get readingClubs;

  /// No description provided for @readingClub.
  ///
  /// In fr, this message translates to:
  /// **'Club de lecture'**
  String get readingClub;

  /// No description provided for @myClubs.
  ///
  /// In fr, this message translates to:
  /// **'Mes clubs'**
  String get myClubs;

  /// No description provided for @myGroups.
  ///
  /// In fr, this message translates to:
  /// **'Mes groupes'**
  String get myGroups;

  /// No description provided for @discover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get discover;

  /// No description provided for @createClub.
  ///
  /// In fr, this message translates to:
  /// **'Créer un Club'**
  String get createClub;

  /// No description provided for @noGroups.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe'**
  String get noGroups;

  /// No description provided for @createOrJoinGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créez ou rejoignez un groupe de lecture'**
  String get createOrJoinGroup;

  /// No description provided for @noPublicGroups.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe public'**
  String get noPublicGroups;

  /// No description provided for @beFirstToCreate.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à créer un groupe public !'**
  String get beFirstToCreate;

  /// No description provided for @privateTag.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get privateTag;

  /// No description provided for @adminTag.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get adminTag;

  /// No description provided for @memberCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} membre{count, plural, =1{} other{s}}'**
  String memberCount(int count);

  /// No description provided for @byCreator.
  ///
  /// In fr, this message translates to:
  /// **'par {name}'**
  String byCreator(String name);

  /// No description provided for @limitReached.
  ///
  /// In fr, this message translates to:
  /// **'Limite atteinte'**
  String get limitReached;

  /// No description provided for @groupLimitMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint la limite de {max} clubs de lecture. Passe à Premium pour en rejoindre autant que tu veux !'**
  String groupLimitMessage(int max);

  /// No description provided for @becomePremium.
  ///
  /// In fr, this message translates to:
  /// **'Devenir Premium'**
  String get becomePremium;

  /// No description provided for @leaveGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe ?'**
  String get leaveGroupTitle;

  /// No description provided for @leaveGroupMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment quitter ce groupe ?'**
  String get leaveGroupMessage;

  /// No description provided for @leftGroup.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe'**
  String get leftGroup;

  /// No description provided for @groupNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Groupe introuvable'**
  String get groupNotFound;

  /// No description provided for @members.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get members;

  /// No description provided for @activities.
  ///
  /// In fr, this message translates to:
  /// **'Activités'**
  String get activities;

  /// No description provided for @activeChallenges.
  ///
  /// In fr, this message translates to:
  /// **'Défis actifs'**
  String get activeChallenges;

  /// No description provided for @createChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Créer un défi'**
  String get createChallenge;

  /// No description provided for @noChallengeActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucun défi actif'**
  String get noChallengeActive;

  /// No description provided for @groupActivities.
  ///
  /// In fr, this message translates to:
  /// **'Activités du groupe'**
  String get groupActivities;

  /// No description provided for @noActivity.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité'**
  String get noActivity;

  /// No description provided for @activitiesWillAppear.
  ///
  /// In fr, this message translates to:
  /// **'Les activités des membres apparaîtront ici'**
  String get activitiesWillAppear;

  /// No description provided for @readPagesOf.
  ///
  /// In fr, this message translates to:
  /// **'a lu {pages} pages de \"{title}\"'**
  String readPagesOf(int pages, String title);

  /// No description provided for @finishedBook.
  ///
  /// In fr, this message translates to:
  /// **'a terminé \"{title}\" 🎉'**
  String finishedBook(String title);

  /// No description provided for @joinedGroup.
  ///
  /// In fr, this message translates to:
  /// **'a rejoint le groupe'**
  String get joinedGroup;

  /// No description provided for @recommendsBook.
  ///
  /// In fr, this message translates to:
  /// **'recommande \"{title}\"'**
  String recommendsBook(String title);

  /// No description provided for @unknownActivity.
  ///
  /// In fr, this message translates to:
  /// **'activité inconnue'**
  String get unknownActivity;

  /// No description provided for @justNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get justNow;

  /// No description provided for @createGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get createGroupTitle;

  /// No description provided for @addPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get addPhoto;

  /// No description provided for @groupNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe *'**
  String get groupNameRequired;

  /// No description provided for @groupNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Club des lecteurs SF'**
  String get groupNameHint;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est requis'**
  String get nameRequired;

  /// No description provided for @descriptionOptional.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get descriptionOptional;

  /// No description provided for @describeGroup.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre groupe de lecture...'**
  String get describeGroup;

  /// No description provided for @privateGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe privé'**
  String get privateGroup;

  /// No description provided for @inviteOnly.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement accessible sur invitation'**
  String get inviteOnly;

  /// No description provided for @visibleToAll.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tous les utilisateurs'**
  String get visibleToAll;

  /// No description provided for @creatorAdminInfo.
  ///
  /// In fr, this message translates to:
  /// **'En tant que créateur, vous serez automatiquement administrateur du groupe et pourrez inviter d\'autres membres.'**
  String get creatorAdminInfo;

  /// No description provided for @createGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer le groupe'**
  String get createGroup;

  /// No description provided for @groupCreated.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé avec succès!'**
  String get groupCreated;

  /// No description provided for @allFriendsInGroup.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos amis sont déjà membres du groupe'**
  String get allFriendsInGroup;

  /// No description provided for @inviteFriend.
  ///
  /// In fr, this message translates to:
  /// **'Inviter un ami'**
  String get inviteFriend;

  /// No description provided for @invitationSent.
  ///
  /// In fr, this message translates to:
  /// **'✅ Invitation envoyée à {name}'**
  String invitationSent(String name);

  /// No description provided for @roleUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Rôle de {name} mis à jour'**
  String roleUpdated(String name);

  /// No description provided for @removeFromGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe ?'**
  String get removeFromGroupTitle;

  /// No description provided for @removeFromGroupMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous retirer {name} du groupe ?'**
  String removeFromGroupMessage(String name);

  /// No description provided for @removeButton.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get removeButton;

  /// No description provided for @memberRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été retiré du groupe'**
  String memberRemoved(String name);

  /// No description provided for @demoteToMember.
  ///
  /// In fr, this message translates to:
  /// **'Rétrograder en membre'**
  String get demoteToMember;

  /// No description provided for @promoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir admin'**
  String get promoteAdmin;

  /// No description provided for @removeFromGroup.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe'**
  String get removeFromGroup;

  /// No description provided for @membersCount.
  ///
  /// In fr, this message translates to:
  /// **'Membres ({count})'**
  String membersCount(int count);

  /// No description provided for @noMembers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre'**
  String get noMembers;

  /// No description provided for @youTag.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get youTag;

  /// No description provided for @administrator.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get administrator;

  /// No description provided for @memberRole.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get memberRole;

  /// No description provided for @photoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Photo mise à jour'**
  String get photoUpdated;

  /// No description provided for @changesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Modifications enregistrées'**
  String get changesSaved;

  /// No description provided for @deleteGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe ?'**
  String get deleteGroupTitle;

  /// No description provided for @deleteGroupMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Tous les membres seront retirés et les données du groupe seront perdues.'**
  String get deleteGroupMessage;

  /// No description provided for @deleteButton.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get deleteButton;

  /// No description provided for @confirmDeleteGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la suppression'**
  String get confirmDeleteGroupTitle;

  /// No description provided for @confirmDeleteGroupMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer \"{name}\" définitivement ?'**
  String confirmDeleteGroupMessage(String name);

  /// No description provided for @groupDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Groupe supprimé'**
  String get groupDeleted;

  /// No description provided for @currentReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture du moment'**
  String get currentReading;

  /// No description provided for @noCurrentReading.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre en cours'**
  String get noCurrentReading;

  /// No description provided for @setCurrentReading.
  ///
  /// In fr, this message translates to:
  /// **'Définir la lecture du groupe'**
  String get setCurrentReading;

  /// No description provided for @inviteMembers.
  ///
  /// In fr, this message translates to:
  /// **'Inviter des membres'**
  String get inviteMembers;

  /// No description provided for @changeImage.
  ///
  /// In fr, this message translates to:
  /// **'Changer l\'image'**
  String get changeImage;

  /// No description provided for @groupSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages du groupe'**
  String get groupSettings;

  /// No description provided for @groupPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo du groupe'**
  String get groupPhoto;

  /// No description provided for @information.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get information;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @visibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get visibility;

  /// No description provided for @publicGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe public'**
  String get publicGroup;

  /// No description provided for @saveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get saveChanges;

  /// No description provided for @manageMembers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les membres'**
  String get manageMembers;

  /// No description provided for @manageMembersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voir, inviter et gérer les rôles'**
  String get manageMembersSubtitle;

  /// No description provided for @deleteChallengeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le défi ?'**
  String get deleteChallengeTitle;

  /// No description provided for @deleteChallengeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get deleteChallengeMessage;

  /// No description provided for @challengeDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Défi supprimé'**
  String get challengeDeleted;

  /// No description provided for @expired.
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get expired;

  /// No description provided for @daysRemaining.
  ///
  /// In fr, this message translates to:
  /// **'{days}j restants'**
  String daysRemaining(int days);

  /// No description provided for @hoursRemaining.
  ///
  /// In fr, this message translates to:
  /// **'{hours}h restantes'**
  String hoursRemaining(int hours);

  /// No description provided for @minutesRemaining.
  ///
  /// In fr, this message translates to:
  /// **'{minutes}min restantes'**
  String minutesRemaining(int minutes);

  /// No description provided for @readABook.
  ///
  /// In fr, this message translates to:
  /// **'Lire un livre'**
  String get readABook;

  /// No description provided for @pagesToRead.
  ///
  /// In fr, this message translates to:
  /// **'{count} pages à lire'**
  String pagesToRead(int count);

  /// No description provided for @dailyChallenge.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min/jour pendant {days} jours'**
  String dailyChallenge(int minutes, int days);

  /// No description provided for @challengeDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail du défi'**
  String get challengeDetail;

  /// No description provided for @leaveChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le défi'**
  String get leaveChallenge;

  /// No description provided for @joinChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le défi'**
  String get joinChallenge;

  /// No description provided for @leftChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le défi'**
  String get leftChallenge;

  /// No description provided for @joinedChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Vous participez au défi !'**
  String get joinedChallenge;

  /// No description provided for @participantsCount.
  ///
  /// In fr, this message translates to:
  /// **'Participants ({count})'**
  String participantsCount(int count);

  /// No description provided for @noParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant'**
  String get noParticipants;

  /// No description provided for @challengeCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Terminé !'**
  String get challengeCompleted;

  /// No description provided for @challengeInProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours...'**
  String get challengeInProgress;

  /// No description provided for @progressPages.
  ///
  /// In fr, this message translates to:
  /// **'{progress} / {target} pages'**
  String progressPages(int progress, int target);

  /// No description provided for @progressDays.
  ///
  /// In fr, this message translates to:
  /// **'{progress} / {target} jours'**
  String progressDays(int progress, int target);

  /// No description provided for @myProgress.
  ///
  /// In fr, this message translates to:
  /// **'Ma progression'**
  String get myProgress;

  /// No description provided for @completedTag.
  ///
  /// In fr, this message translates to:
  /// **'Complété'**
  String get completedTag;

  /// No description provided for @newChallenge.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau défi'**
  String get newChallenge;

  /// No description provided for @challengeType.
  ///
  /// In fr, this message translates to:
  /// **'Type de défi'**
  String get challengeType;

  /// No description provided for @challengeTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Titre du défi *'**
  String get challengeTitleRequired;

  /// No description provided for @challengeTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Marathon de lecture'**
  String get challengeTitleHint;

  /// No description provided for @titleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le titre est requis'**
  String get titleRequired;

  /// No description provided for @startDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de début'**
  String get startDate;

  /// No description provided for @startsOn.
  ///
  /// In fr, this message translates to:
  /// **'Commence le'**
  String get startsOn;

  /// No description provided for @startsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get startsToday;

  /// No description provided for @upcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get upcoming;

  /// No description provided for @daysUntilStart.
  ///
  /// In fr, this message translates to:
  /// **'Dans {days}j'**
  String daysUntilStart(int days);

  /// No description provided for @challengeStartNotifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le défi commence aujourd\'hui !'**
  String get challengeStartNotifTitle;

  /// No description provided for @deadline.
  ///
  /// In fr, this message translates to:
  /// **'Date limite'**
  String get deadline;

  /// No description provided for @createChallengeBtn.
  ///
  /// In fr, this message translates to:
  /// **'Créer le défi'**
  String get createChallengeBtn;

  /// No description provided for @challengeCreated.
  ///
  /// In fr, this message translates to:
  /// **'Défi créé !'**
  String get challengeCreated;

  /// No description provided for @pagesType.
  ///
  /// In fr, this message translates to:
  /// **'Pages'**
  String get pagesType;

  /// No description provided for @bookType.
  ///
  /// In fr, this message translates to:
  /// **'Livre'**
  String get bookType;

  /// No description provided for @dailyType.
  ///
  /// In fr, this message translates to:
  /// **'Quotidien'**
  String get dailyType;

  /// No description provided for @bookToRead.
  ///
  /// In fr, this message translates to:
  /// **'Livre à lire'**
  String get bookToRead;

  /// No description provided for @goalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Objectif'**
  String get goalLabel;

  /// No description provided for @pagesCountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de pages *'**
  String get pagesCountRequired;

  /// No description provided for @pagesCountHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 200'**
  String get pagesCountHint;

  /// No description provided for @pagesUnit.
  ///
  /// In fr, this message translates to:
  /// **'pages'**
  String get pagesUnit;

  /// No description provided for @required.
  ///
  /// In fr, this message translates to:
  /// **'Requis'**
  String get required;

  /// No description provided for @invalidNumber.
  ///
  /// In fr, this message translates to:
  /// **'Nombre invalide'**
  String get invalidNumber;

  /// No description provided for @dailyGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif quotidien'**
  String get dailyGoal;

  /// No description provided for @dailyMinutesRequired.
  ///
  /// In fr, this message translates to:
  /// **'Minutes de lecture par jour *'**
  String get dailyMinutesRequired;

  /// No description provided for @dailyMinutesHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 30'**
  String get dailyMinutesHint;

  /// No description provided for @minPerDay.
  ///
  /// In fr, this message translates to:
  /// **'min/jour'**
  String get minPerDay;

  /// No description provided for @daysCountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de jours *'**
  String get daysCountRequired;

  /// No description provided for @daysCountHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 7'**
  String get daysCountHint;

  /// No description provided for @daysUnit.
  ///
  /// In fr, this message translates to:
  /// **'jours'**
  String get daysUnit;

  /// No description provided for @oneWeek.
  ///
  /// In fr, this message translates to:
  /// **'1 sem.'**
  String get oneWeek;

  /// No description provided for @twoWeeks.
  ///
  /// In fr, this message translates to:
  /// **'2 sem.'**
  String get twoWeeks;

  /// No description provided for @oneMonth.
  ///
  /// In fr, this message translates to:
  /// **'1 mois'**
  String get oneMonth;

  /// No description provided for @expiresOn.
  ///
  /// In fr, this message translates to:
  /// **'Expire le'**
  String get expiresOn;

  /// No description provided for @chooseBook.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un livre'**
  String get chooseBook;

  /// No description provided for @searchBookHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un livre...'**
  String get searchBookHint;

  /// No description provided for @noResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get noResult;

  /// No description provided for @selectBookPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner un livre'**
  String get selectBookPrompt;

  /// No description provided for @readBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lire \"{title}\"'**
  String readBookTitle(String title);

  /// No description provided for @privateProfileLabel.
  ///
  /// In fr, this message translates to:
  /// **'Profil privé'**
  String get privateProfileLabel;

  /// No description provided for @privateProfileMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ce profil est privé. Ajoutez {name} en ami pour voir ses statistiques.'**
  String privateProfileMessage(String name);

  /// No description provided for @books.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get books;

  /// No description provided for @viewFullProfile.
  ///
  /// In fr, this message translates to:
  /// **'Voir le profil complet'**
  String get viewFullProfile;

  /// No description provided for @followLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter cet ami'**
  String get followLabel;

  /// No description provided for @pagesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pages'**
  String get pagesLabel;

  /// No description provided for @readingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get readingLabel;

  /// No description provided for @flowLabel.
  ///
  /// In fr, this message translates to:
  /// **'Flow'**
  String get flowLabel;

  /// No description provided for @recentActivity.
  ///
  /// In fr, this message translates to:
  /// **'Activité récente'**
  String get recentActivity;

  /// No description provided for @noRecentActivity.
  ///
  /// In fr, this message translates to:
  /// **'Aucune activité récente'**
  String get noRecentActivity;

  /// No description provided for @theirBadges.
  ///
  /// In fr, this message translates to:
  /// **'Ses badges'**
  String get theirBadges;

  /// No description provided for @removeFriend.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des amis'**
  String get removeFriend;

  /// No description provided for @cancelRequest.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la demande'**
  String get cancelRequest;

  /// No description provided for @addFriend.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter en ami'**
  String get addFriend;

  /// No description provided for @removeFriendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet ami ?'**
  String get removeFriendTitle;

  /// No description provided for @removeFriendMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous retirer {name} de vos amis ?'**
  String removeFriendMessage(String name);

  /// No description provided for @requestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée'**
  String get requestSent;

  /// No description provided for @requestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get requestCancelled;

  /// No description provided for @friendRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Ami retiré'**
  String get friendRemoved;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {days} jours'**
  String daysAgo(int days);

  /// No description provided for @myFriends.
  ///
  /// In fr, this message translates to:
  /// **'Mes amis'**
  String get myFriends;

  /// No description provided for @findFriends.
  ///
  /// In fr, this message translates to:
  /// **'Trouver des amis'**
  String get findFriends;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @noFriendFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun ami trouvé'**
  String get noFriendFound;

  /// No description provided for @addFriendsToSeeActivityMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des amis pour voir leur activité !'**
  String get addFriendsToSeeActivityMessage;

  /// No description provided for @friendRemovedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Ami retiré'**
  String get friendRemovedSnack;

  /// No description provided for @cannotRemoveFriend.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer cet ami: {error}'**
  String cannotRemoveFriend(String error);

  /// No description provided for @searchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchLabel;

  /// No description provided for @friends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friends;

  /// No description provided for @groups.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groups;

  /// No description provided for @searchByName.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom'**
  String get searchByName;

  /// No description provided for @groupName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupName;

  /// No description provided for @inviteToRead.
  ///
  /// In fr, this message translates to:
  /// **'Invite tes amis à lire'**
  String get inviteToRead;

  /// No description provided for @shareWhatYouRead.
  ///
  /// In fr, this message translates to:
  /// **'Partage ce que tu lis en ce moment'**
  String get shareWhatYouRead;

  /// No description provided for @typeMin2Chars.
  ///
  /// In fr, this message translates to:
  /// **'Tape au moins 2 caractères pour chercher'**
  String get typeMin2Chars;

  /// No description provided for @invitationSentShort.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée'**
  String get invitationSentShort;

  /// No description provided for @cannotAddFriend.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter cet ami'**
  String get cannotAddFriend;

  /// No description provided for @cannotCancelRequest.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'annuler la demande'**
  String get cannotCancelRequest;

  /// No description provided for @relationAlreadyExists.
  ///
  /// In fr, this message translates to:
  /// **'Relation déjà {status}'**
  String relationAlreadyExists(String status);

  /// No description provided for @invalidUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur invalide'**
  String get invalidUser;

  /// No description provided for @connectToAddFriend.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour ajouter un ami'**
  String get connectToAddFriend;

  /// No description provided for @errorDuringSearch.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la recherche'**
  String get errorDuringSearch;

  /// No description provided for @firstSessionBravo.
  ///
  /// In fr, this message translates to:
  /// **'Bravo pour ta première\nsession de lecture !'**
  String get firstSessionBravo;

  /// No description provided for @friendsReadToo.
  ///
  /// In fr, this message translates to:
  /// **'Tes amis lisent aussi.\nAjoute-les pour voir leur activité !'**
  String get friendsReadToo;

  /// No description provided for @findMyFriends.
  ///
  /// In fr, this message translates to:
  /// **'Trouver mes amis'**
  String get findMyFriends;

  /// No description provided for @searchingContacts.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de tes amis...'**
  String get searchingContacts;

  /// No description provided for @noContactOnLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact n\'utilise encore LexDay'**
  String get noContactOnLexDay;

  /// No description provided for @friendsFoundOnLexDay.
  ///
  /// In fr, this message translates to:
  /// **'{count} ami{count, plural, =1{} other{s}} trouvé{count, plural, =1{} other{s}} sur LexDay'**
  String friendsFoundOnLexDay(int count);

  /// No description provided for @inviteFriendsToJoin.
  ///
  /// In fr, this message translates to:
  /// **'Invite tes amis à rejoindre LexDay !'**
  String get inviteFriendsToJoin;

  /// No description provided for @sent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé'**
  String get sent;

  /// No description provided for @contactsAccessDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès aux contacts refusé'**
  String get contactsAccessDenied;

  /// No description provided for @cannotAccessContacts.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder aux contacts'**
  String get cannotAccessContacts;

  /// No description provided for @authorizeContactsSettings.
  ///
  /// In fr, this message translates to:
  /// **'Pour trouver tes amis, autorise l\'accès aux contacts dans les réglages.'**
  String get authorizeContactsSettings;

  /// No description provided for @errorOccurredRetryLater.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessaie plus tard.'**
  String get errorOccurredRetryLater;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get openSettings;

  /// No description provided for @findContactsFriends.
  ///
  /// In fr, this message translates to:
  /// **'Trouver des amis'**
  String get findContactsFriends;

  /// No description provided for @searchingYourContacts.
  ///
  /// In fr, this message translates to:
  /// **'Recherche dans tes contacts...'**
  String get searchingYourContacts;

  /// No description provided for @noContactFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact trouvé'**
  String get noContactFound;

  /// No description provided for @contactsNotOnLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Tes contacts ne semblent pas encore utiliser LexDay.'**
  String get contactsNotOnLexDay;

  /// No description provided for @alreadyOnLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Déjà sur LexDay'**
  String get alreadyOnLexDay;

  /// No description provided for @inviteToLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Inviter sur LexDay'**
  String get inviteToLexDay;

  /// No description provided for @invited.
  ///
  /// In fr, this message translates to:
  /// **'Invité'**
  String get invited;

  /// No description provided for @invite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get invite;

  /// No description provided for @authorizeContacts.
  ///
  /// In fr, this message translates to:
  /// **'Pour trouver tes amis, autorise l\'accès à tes contacts.'**
  String get authorizeContacts;

  /// No description provided for @cannotAccessContactsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder à tes contacts. Réessaie plus tard.'**
  String get cannotAccessContactsRetry;

  /// No description provided for @errorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorOccurred;

  /// No description provided for @shareInviteToLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins-moi sur LexDay pour suivre nos lectures ensemble ! Télécharge l\'app : https://readon.app'**
  String get shareInviteToLexDay;

  /// No description provided for @friendRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'amis'**
  String get friendRequests;

  /// No description provided for @cannotGetRequests.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer les demandes'**
  String get cannotGetRequests;

  /// No description provided for @friendAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ami ajouté'**
  String get friendAdded;

  /// No description provided for @requestDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get requestDeclined;

  /// No description provided for @actionImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible'**
  String get actionImpossible;

  /// No description provided for @noRequest.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande'**
  String get noRequest;

  /// No description provided for @museGreeting.
  ///
  /// In fr, this message translates to:
  /// **'Salut, je suis Muse, ta conseillère lecture. Qu\'as-tu envie de lire ?'**
  String get museGreeting;

  /// No description provided for @museRecommendNovel.
  ///
  /// In fr, this message translates to:
  /// **'Recommande-moi un roman'**
  String get museRecommendNovel;

  /// No description provided for @museSimilarBook.
  ///
  /// In fr, this message translates to:
  /// **'Un livre similaire à mon dernier'**
  String get museSimilarBook;

  /// No description provided for @museClassic.
  ///
  /// In fr, this message translates to:
  /// **'Un classique à découvrir'**
  String get museClassic;

  /// No description provided for @freeMessagesUsed.
  ///
  /// In fr, this message translates to:
  /// **'Tu as utilisé tes {max} messages gratuits ce mois-ci'**
  String freeMessagesUsed(int max);

  /// No description provided for @subscribeForUnlimited.
  ///
  /// In fr, this message translates to:
  /// **'Abonne-toi pour discuter sans limite avec Muse !'**
  String get subscribeForUnlimited;

  /// No description provided for @discoverSubscription.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir l\'abonnement'**
  String get discoverSubscription;

  /// No description provided for @askRecommendation.
  ///
  /// In fr, this message translates to:
  /// **'Demande une recommandation...'**
  String get askRecommendation;

  /// No description provided for @cannotLoadBook.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le livre : {error}'**
  String cannotLoadBook(String error);

  /// No description provided for @inBookstore.
  ///
  /// In fr, this message translates to:
  /// **'En librairie'**
  String get inBookstore;

  /// No description provided for @findNearMe.
  ///
  /// In fr, this message translates to:
  /// **'Trouver près de moi'**
  String get findNearMe;

  /// No description provided for @enableLocationSettings.
  ///
  /// In fr, this message translates to:
  /// **'Activez la localisation dans les réglages'**
  String get enableLocationSettings;

  /// No description provided for @locationAccessRequired.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la localisation requis'**
  String get locationAccessRequired;

  /// No description provided for @addToList.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à une liste'**
  String get addToList;

  /// No description provided for @noPersonalList.
  ///
  /// In fr, this message translates to:
  /// **'Aucune liste personnelle.'**
  String get noPersonalList;

  /// No description provided for @createNewList.
  ///
  /// In fr, this message translates to:
  /// **'Créer une nouvelle liste'**
  String get createNewList;

  /// No description provided for @addedToList.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à \"{title}\"'**
  String addedToList(String title);

  /// No description provided for @deleteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la conversation'**
  String get deleteConversation;

  /// No description provided for @deleteConversationConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Es-tu sûr de vouloir supprimer cette conversation ?'**
  String get deleteConversationConfirm;

  /// No description provided for @unlimitedChatbot.
  ///
  /// In fr, this message translates to:
  /// **'Utilisation illimitée du chatbot, abonnez-vous'**
  String get unlimitedChatbot;

  /// No description provided for @messagesUsedCount.
  ///
  /// In fr, this message translates to:
  /// **'{used}/{max} messages utilisés ce mois-ci'**
  String messagesUsedCount(int used, int max);

  /// No description provided for @noConversation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation'**
  String get noConversation;

  /// No description provided for @startConversationMuse.
  ///
  /// In fr, this message translates to:
  /// **'Démarre une conversation avec Muse pour obtenir des recommandations de livres personnalisées.'**
  String get startConversationMuse;

  /// No description provided for @newConversation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get newConversation;

  /// No description provided for @readingLists.
  ///
  /// In fr, this message translates to:
  /// **'Listes de lecture'**
  String get readingLists;

  /// No description provided for @nBooks.
  ///
  /// In fr, this message translates to:
  /// **'{count} livres'**
  String nBooks(int count);

  /// No description provided for @nReaders.
  ///
  /// In fr, this message translates to:
  /// **'{count} lecteur{count, plural, =1{} other{s}}'**
  String nReaders(int count);

  /// No description provided for @nRead.
  ///
  /// In fr, this message translates to:
  /// **'{read}/{total} lus'**
  String nRead(int read, int total);

  /// No description provided for @deleteListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette liste ?'**
  String get deleteListTitle;

  /// No description provided for @deleteListMessage.
  ///
  /// In fr, this message translates to:
  /// **'La liste \"{title}\" sera définitivement supprimée.'**
  String deleteListMessage(String title);

  /// No description provided for @editButton.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get editButton;

  /// No description provided for @addBookToList.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un livre'**
  String get addBookToList;

  /// No description provided for @noBooksInList.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre dans cette liste'**
  String get noBooksInList;

  /// No description provided for @addBooksFromLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute des livres depuis ta bibliothèque ou en recherchant un titre.'**
  String get addBooksFromLibrary;

  /// No description provided for @removeBookTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce livre ?'**
  String get removeBookTitle;

  /// No description provided for @removeBookMessage.
  ///
  /// In fr, this message translates to:
  /// **'Retirer \"{title}\" de cette liste ?'**
  String removeBookMessage(String title);

  /// No description provided for @removeFromLibraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer de ma bibliothèque ?'**
  String get removeFromLibraryTitle;

  /// No description provided for @removeFromLibraryMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{title}\" définitivement de ta bibliothèque ?'**
  String removeFromLibraryMessage(String title);

  /// No description provided for @removeFromLibraryAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get removeFromLibraryAction;

  /// No description provided for @bookRemovedFromLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Livre supprimé de ta bibliothèque'**
  String get bookRemovedFromLibrary;

  /// No description provided for @myListsSection.
  ///
  /// In fr, this message translates to:
  /// **'Mes listes'**
  String get myListsSection;

  /// No description provided for @savedLists.
  ///
  /// In fr, this message translates to:
  /// **'Listes sauvegardées'**
  String get savedLists;

  /// No description provided for @noList.
  ///
  /// In fr, this message translates to:
  /// **'Aucune liste'**
  String get noList;

  /// No description provided for @createListCta.
  ///
  /// In fr, this message translates to:
  /// **'Crée ta propre liste de lecture ou découvre nos sélections curatées.'**
  String get createListCta;

  /// No description provided for @createList.
  ///
  /// In fr, this message translates to:
  /// **'Créer une liste'**
  String get createList;

  /// No description provided for @listLimitMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as atteint la limite de {max} listes de lecture. Passe à Premium pour en créer autant que tu veux !'**
  String listLimitMessage(int max);

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @goPremium.
  ///
  /// In fr, this message translates to:
  /// **'Passer Premium'**
  String get goPremium;

  /// No description provided for @editList.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la liste'**
  String get editList;

  /// No description provided for @newList.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle liste'**
  String get newList;

  /// No description provided for @listName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la liste'**
  String get listName;

  /// No description provided for @listNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Livres à lire cet été'**
  String get listNameHint;

  /// No description provided for @iconLabel.
  ///
  /// In fr, this message translates to:
  /// **'Icône'**
  String get iconLabel;

  /// No description provided for @colorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get colorLabel;

  /// No description provided for @createListBtn.
  ///
  /// In fr, this message translates to:
  /// **'Créer la liste'**
  String get createListBtn;

  /// No description provided for @defaultListName.
  ///
  /// In fr, this message translates to:
  /// **'Ma liste'**
  String get defaultListName;

  /// No description provided for @publicList.
  ///
  /// In fr, this message translates to:
  /// **'Liste publique'**
  String get publicList;

  /// No description provided for @privateList.
  ///
  /// In fr, this message translates to:
  /// **'Liste privée'**
  String get privateList;

  /// No description provided for @publicListDescription.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tes amis sur ton profil'**
  String get publicListDescription;

  /// No description provided for @privateListDescription.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement par toi'**
  String get privateListDescription;

  /// No description provided for @addBooksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des livres'**
  String get addBooksTitle;

  /// No description provided for @myLibraryTab.
  ///
  /// In fr, this message translates to:
  /// **'Ma bibliothèque'**
  String get myLibraryTab;

  /// No description provided for @searchTab.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchTab;

  /// No description provided for @emptyLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque vide'**
  String get emptyLibrary;

  /// No description provided for @useSearchTab.
  ///
  /// In fr, this message translates to:
  /// **'Utilise l\'onglet Rechercher pour trouver et ajouter des livres.'**
  String get useSearchTab;

  /// No description provided for @filterLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer ma bibliothèque...'**
  String get filterLibrary;

  /// No description provided for @searchTitleAuthor.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un titre ou un auteur...'**
  String get searchTitleAuthor;

  /// No description provided for @tryMoreSpecific.
  ///
  /// In fr, this message translates to:
  /// **'Essaie avec un titre plus précis'**
  String get tryMoreSpecific;

  /// No description provided for @searchByTitleAuthor.
  ///
  /// In fr, this message translates to:
  /// **'Recherche un livre par titre ou auteur'**
  String get searchByTitleAuthor;

  /// No description provided for @noReadingSession.
  ///
  /// In fr, this message translates to:
  /// **'Aucune session de lecture'**
  String get noReadingSession;

  /// No description provided for @startSessionPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Lancez une session pour commencer !'**
  String get startSessionPrompt;

  /// No description provided for @unknownBook.
  ///
  /// In fr, this message translates to:
  /// **'Livre inconnu'**
  String get unknownBook;

  /// No description provided for @inProgressTag.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get inProgressTag;

  /// No description provided for @nPagesRead.
  ///
  /// In fr, this message translates to:
  /// **'{count} pages'**
  String nPagesRead(int count);

  /// No description provided for @thisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In fr, this message translates to:
  /// **'Ce mois'**
  String get thisMonth;

  /// No description provided for @sessionTag.
  ///
  /// In fr, this message translates to:
  /// **'SESSION'**
  String get sessionTag;

  /// No description provided for @makeVisible.
  ///
  /// In fr, this message translates to:
  /// **'Rendre visible'**
  String get makeVisible;

  /// No description provided for @hideSessionBtn.
  ///
  /// In fr, this message translates to:
  /// **'Masquer la session'**
  String get hideSessionBtn;

  /// No description provided for @sessionHiddenInfo.
  ///
  /// In fr, this message translates to:
  /// **'Session masquée des classements et du feed'**
  String get sessionHiddenInfo;

  /// No description provided for @bookProgression.
  ///
  /// In fr, this message translates to:
  /// **'Progression du livre'**
  String get bookProgression;

  /// No description provided for @durationLabel.
  ///
  /// In fr, this message translates to:
  /// **'durée'**
  String get durationLabel;

  /// No description provided for @pagesReadLabel.
  ///
  /// In fr, this message translates to:
  /// **'pages lues'**
  String get pagesReadLabel;

  /// No description provided for @paceLabel.
  ///
  /// In fr, this message translates to:
  /// **'rythme'**
  String get paceLabel;

  /// No description provided for @sessionProgression.
  ///
  /// In fr, this message translates to:
  /// **'Progression de la session'**
  String get sessionProgression;

  /// No description provided for @plusPages.
  ///
  /// In fr, this message translates to:
  /// **'+{count} pages'**
  String plusPages(int count);

  /// No description provided for @startLabel.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get endLabel;

  /// No description provided for @timeline.
  ///
  /// In fr, this message translates to:
  /// **'Chronologie'**
  String get timeline;

  /// No description provided for @sessionStart.
  ///
  /// In fr, this message translates to:
  /// **'début de session'**
  String get sessionStart;

  /// No description provided for @ofReadingDuration.
  ///
  /// In fr, this message translates to:
  /// **'{duration} de lecture'**
  String ofReadingDuration(String duration);

  /// No description provided for @sessionEnd.
  ///
  /// In fr, this message translates to:
  /// **'fin de session'**
  String get sessionEnd;

  /// No description provided for @unlockInsights.
  ///
  /// In fr, this message translates to:
  /// **'✨ Débloquer tes insights'**
  String get unlockInsights;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la session'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer cette session de lecture ? Cette action est irréversible.'**
  String get deleteSessionMessage;

  /// No description provided for @sessionVisible.
  ///
  /// In fr, this message translates to:
  /// **'Session visible dans les classements'**
  String get sessionVisible;

  /// No description provided for @errorModifying.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la modification'**
  String get errorModifying;

  /// No description provided for @errorDeleting.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get errorDeleting;

  /// No description provided for @loadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get loadingError;

  /// No description provided for @pagesReadByMonth.
  ///
  /// In fr, this message translates to:
  /// **'Pages lues par mois'**
  String get pagesReadByMonth;

  /// No description provided for @genreDistribution.
  ///
  /// In fr, this message translates to:
  /// **'Répartition des genres'**
  String get genreDistribution;

  /// No description provided for @whenDoYouRead.
  ///
  /// In fr, this message translates to:
  /// **'Quand lis-tu'**
  String get whenDoYouRead;

  /// No description provided for @favoriteSchedules.
  ///
  /// In fr, this message translates to:
  /// **'Tes horaires favoris de la semaine'**
  String get favoriteSchedules;

  /// No description provided for @yourGoals.
  ///
  /// In fr, this message translates to:
  /// **'Tes objectifs'**
  String get yourGoals;

  /// No description provided for @noGoalDefined.
  ///
  /// In fr, this message translates to:
  /// **'Aucun objectif défini'**
  String get noGoalDefined;

  /// No description provided for @defineGoals.
  ///
  /// In fr, this message translates to:
  /// **'Définir tes objectifs'**
  String get defineGoals;

  /// No description provided for @notifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @readingReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de lecture'**
  String get readingReminders;

  /// No description provided for @remindersDescription.
  ///
  /// In fr, this message translates to:
  /// **'Reste motivé avec des rappels quotidiens pour maintenir ton flow de lecture.'**
  String get remindersDescription;

  /// No description provided for @enableNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get enableNotifications;

  /// No description provided for @receiveDailyReminders.
  ///
  /// In fr, this message translates to:
  /// **'Reçois des rappels quotidiens'**
  String get receiveDailyReminders;

  /// No description provided for @reminderDays.
  ///
  /// In fr, this message translates to:
  /// **'Jours de rappel'**
  String get reminderDays;

  /// No description provided for @whichDays.
  ///
  /// In fr, this message translates to:
  /// **'Quels jours veux-tu être notifié ?'**
  String get whichDays;

  /// No description provided for @reminderTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure du rappel'**
  String get reminderTime;

  /// No description provided for @whenReminder.
  ///
  /// In fr, this message translates to:
  /// **'Quand veux-tu recevoir le rappel ?'**
  String get whenReminder;

  /// No description provided for @aboutNotifications.
  ///
  /// In fr, this message translates to:
  /// **'À propos des notifications'**
  String get aboutNotifications;

  /// No description provided for @notificationInfo.
  ///
  /// In fr, this message translates to:
  /// **'Tu recevras une notification les jours sélectionnés pour te rappeler de lire et maintenir ton flow.'**
  String get notificationInfo;

  /// No description provided for @notificationCenter.
  ///
  /// In fr, this message translates to:
  /// **'Centre de notifications'**
  String get notificationCenter;

  /// No description provided for @notificationCenterDescription.
  ///
  /// In fr, this message translates to:
  /// **'Gère tes préférences de notifications.'**
  String get notificationCenterDescription;

  /// No description provided for @friendRequestNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'ami'**
  String get friendRequestNotifications;

  /// No description provided for @friendRequestNotificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Être notifié des nouvelles demandes d\'ami'**
  String get friendRequestNotificationsDesc;

  /// No description provided for @emailSection.
  ///
  /// In fr, this message translates to:
  /// **'Emails'**
  String get emailSection;

  /// No description provided for @emailSectionDescription.
  ///
  /// In fr, this message translates to:
  /// **'Choisis les notifications que tu veux recevoir par email.'**
  String get emailSectionDescription;

  /// No description provided for @friendRequestEmail.
  ///
  /// In fr, this message translates to:
  /// **'Demandes d\'ami par email'**
  String get friendRequestEmail;

  /// No description provided for @friendRequestEmailDesc.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un email quand quelqu\'un t\'envoie une demande d\'ami'**
  String get friendRequestEmailDesc;

  /// No description provided for @pushSection.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push'**
  String get pushSection;

  /// No description provided for @pushSectionDescription.
  ///
  /// In fr, this message translates to:
  /// **'Notifications sur ton appareil.'**
  String get pushSectionDescription;

  /// No description provided for @settingsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Préférences enregistrées'**
  String get settingsSaved;

  /// No description provided for @myGoals.
  ///
  /// In fr, this message translates to:
  /// **'Mes objectifs'**
  String get myGoals;

  /// No description provided for @goalsDescription.
  ///
  /// In fr, this message translates to:
  /// **'Personnalise tes objectifs pour rester motivé et suivre ta progression.'**
  String get goalsDescription;

  /// No description provided for @goalsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs enregistrés !'**
  String get goalsSaved;

  /// No description provided for @freeGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif libre'**
  String get freeGoal;

  /// No description provided for @selectedGoals.
  ///
  /// In fr, this message translates to:
  /// **'💡 Objectifs sélectionnés'**
  String get selectedGoals;

  /// No description provided for @goalPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Objectif :'**
  String get goalPrefix;

  /// No description provided for @saveMyGoals.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer mes objectifs'**
  String get saveMyGoals;

  /// No description provided for @goalsModifiable.
  ///
  /// In fr, this message translates to:
  /// **'Tu pourras modifier tes objectifs à tout moment'**
  String get goalsModifiable;

  /// No description provided for @upgradeToLabel.
  ///
  /// In fr, this message translates to:
  /// **'Passez à'**
  String get upgradeToLabel;

  /// No description provided for @lexdayPremium.
  ///
  /// In fr, this message translates to:
  /// **'LexDay Premium'**
  String get lexdayPremium;

  /// No description provided for @unlockPotential.
  ///
  /// In fr, this message translates to:
  /// **'Débloquez tout le potentiel de votre lecture'**
  String get unlockPotential;

  /// No description provided for @whatPremiumUnlocks.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Premium débloque'**
  String get whatPremiumUnlocks;

  /// No description provided for @seeLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get seeLess;

  /// No description provided for @moreFeatures.
  ///
  /// In fr, this message translates to:
  /// **'+{count} fonctionnalités'**
  String moreFeatures(int count);

  /// No description provided for @choosePlan.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un plan'**
  String get choosePlan;

  /// No description provided for @cannotLoadOffers.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les offres'**
  String get cannotLoadOffers;

  /// No description provided for @startFreeTrial.
  ///
  /// In fr, this message translates to:
  /// **'Commencer l\'essai gratuit'**
  String get startFreeTrial;

  /// No description provided for @subscribe.
  ///
  /// In fr, this message translates to:
  /// **'S\'abonner'**
  String get subscribe;

  /// No description provided for @freeTrialInfo.
  ///
  /// In fr, this message translates to:
  /// **'Essai gratuit de 7 jours. Aucun paiement immédiat.\nAnnulable à tout moment.'**
  String get freeTrialInfo;

  /// No description provided for @monthlyBillingInfo.
  ///
  /// In fr, this message translates to:
  /// **'Facturé chaque mois. Annulable à tout moment.'**
  String get monthlyBillingInfo;

  /// No description provided for @restorePurchases.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer mes achats'**
  String get restorePurchases;

  /// No description provided for @termsOfUse.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get termsOfUse;

  /// No description provided for @welcomePremium.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans LexDay Premium !'**
  String get welcomePremium;

  /// No description provided for @subscriptionRestored.
  ///
  /// In fr, this message translates to:
  /// **'Abonnement restauré !'**
  String get subscriptionRestored;

  /// No description provided for @noSubscriptionFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun abonnement trouvé'**
  String get noSubscriptionFound;

  /// No description provided for @featureHeader.
  ///
  /// In fr, this message translates to:
  /// **'FONCTIONNALITÉ'**
  String get featureHeader;

  /// No description provided for @freeHeader.
  ///
  /// In fr, this message translates to:
  /// **'GRATUIT'**
  String get freeHeader;

  /// No description provided for @premiumHeader.
  ///
  /// In fr, this message translates to:
  /// **'PREMIUM'**
  String get premiumHeader;

  /// No description provided for @alreadyFree.
  ///
  /// In fr, this message translates to:
  /// **'DÉJÀ INCLUS GRATUITEMENT'**
  String get alreadyFree;

  /// No description provided for @annual.
  ///
  /// In fr, this message translates to:
  /// **'Annuel'**
  String get annual;

  /// No description provided for @monthly.
  ///
  /// In fr, this message translates to:
  /// **'Mensuel'**
  String get monthly;

  /// No description provided for @yourReadingFlow.
  ///
  /// In fr, this message translates to:
  /// **'Ton flow de lecture'**
  String get yourReadingFlow;

  /// No description provided for @consecutiveDaysActive.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours consécutifs, actif'**
  String consecutiveDaysActive(int days);

  /// No description provided for @daysLabel.
  ///
  /// In fr, this message translates to:
  /// **'jours'**
  String get daysLabel;

  /// No description provided for @currentFlow.
  ///
  /// In fr, this message translates to:
  /// **'Flow actuel'**
  String get currentFlow;

  /// No description provided for @totalDays.
  ///
  /// In fr, this message translates to:
  /// **'jours au total'**
  String get totalDays;

  /// No description provided for @recordDays.
  ///
  /// In fr, this message translates to:
  /// **'jours au record'**
  String get recordDays;

  /// No description provided for @flowFreeze.
  ///
  /// In fr, this message translates to:
  /// **'Flow Freeze'**
  String get flowFreeze;

  /// No description provided for @autoFreezeActive.
  ///
  /// In fr, this message translates to:
  /// **'Auto-freeze actif'**
  String get autoFreezeActive;

  /// No description provided for @protect.
  ///
  /// In fr, this message translates to:
  /// **'Protéger'**
  String get protect;

  /// No description provided for @unlimited.
  ///
  /// In fr, this message translates to:
  /// **'Illimité'**
  String get unlimited;

  /// No description provided for @freezesAvailable.
  ///
  /// In fr, this message translates to:
  /// **'{count}/2 dispo'**
  String freezesAvailable(int count);

  /// No description provided for @exhausted.
  ///
  /// In fr, this message translates to:
  /// **'Épuisé'**
  String get exhausted;

  /// No description provided for @premiumAutoFreezes.
  ///
  /// In fr, this message translates to:
  /// **'Passe Premium pour des auto-freezes illimités et le freeze manuel.'**
  String get premiumAutoFreezes;

  /// No description provided for @useFreezeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le freeze ?'**
  String get useFreezeTitle;

  /// No description provided for @useFreezeMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cela protégera ton flow pour hier en utilisant un freeze manuel.'**
  String get useFreezeMessage;

  /// No description provided for @flowHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique du flow'**
  String get flowHistory;

  /// No description provided for @flowHistoryDescription.
  ///
  /// In fr, this message translates to:
  /// **'Navigue dans tout ton historique de lecture mois par mois'**
  String get flowHistoryDescription;

  /// No description provided for @unlockWithPremium.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer avec Premium'**
  String get unlockWithPremium;

  /// No description provided for @beatPercentile.
  ///
  /// In fr, this message translates to:
  /// **'Tu as battu {percentile} % des lecteurs réguliers.'**
  String beatPercentile(int percentile);

  /// No description provided for @bravoExcl.
  ///
  /// In fr, this message translates to:
  /// **'Bravo! '**
  String get bravoExcl;

  /// No description provided for @keepReadingTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Continue ta lecture demain pour maintenir ton flow!'**
  String get keepReadingTomorrow;

  /// No description provided for @iAcceptThe.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les '**
  String get iAcceptThe;

  /// No description provided for @termsOfUseLink.
  ///
  /// In fr, this message translates to:
  /// **'Conditions Générales d\'Utilisation'**
  String get termsOfUseLink;

  /// No description provided for @ofLexDay.
  ///
  /// In fr, this message translates to:
  /// **' de LexDay'**
  String get ofLexDay;

  /// No description provided for @readingNow.
  ///
  /// In fr, this message translates to:
  /// **'En train de lire · {label}'**
  String readingNow(String label);

  /// No description provided for @amazon.
  ///
  /// In fr, this message translates to:
  /// **'Amazon'**
  String get amazon;

  /// No description provided for @libraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'ta collection'**
  String get librarySubtitle;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// No description provided for @filterReading.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get filterReading;

  /// No description provided for @filterRead.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get filterRead;

  /// No description provided for @filterMyLists.
  ///
  /// In fr, this message translates to:
  /// **'Mes listes'**
  String get filterMyLists;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @currentlyReading.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get currentlyReading;

  /// No description provided for @readBooks.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get readBooks;

  /// No description provided for @noCurrentlyReading.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre en cours'**
  String get noCurrentlyReading;

  /// No description provided for @noReadBooks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun livre lu'**
  String get noReadBooks;

  /// No description provided for @allReadingBooks.
  ///
  /// In fr, this message translates to:
  /// **'Livres en cours'**
  String get allReadingBooks;

  /// No description provided for @allFinishedBooks.
  ///
  /// In fr, this message translates to:
  /// **'Livres lus'**
  String get allFinishedBooks;

  /// No description provided for @newSessionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'NOUVELLE SESSION'**
  String get newSessionSubtitle;

  /// No description provided for @startSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get startSessionTitle;

  /// No description provided for @whatPageAreYouAt.
  ///
  /// In fr, this message translates to:
  /// **'À QUELLE PAGE ES-TU ?'**
  String get whatPageAreYouAt;

  /// No description provided for @scanPageBtn.
  ///
  /// In fr, this message translates to:
  /// **'Scanner la page'**
  String get scanPageBtn;

  /// No description provided for @galleryPageBtn.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get galleryPageBtn;

  /// No description provided for @launchSessionBtn.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la session'**
  String get launchSessionBtn;

  /// No description provided for @continueFromPage.
  ///
  /// In fr, this message translates to:
  /// **'Continuer depuis la page {page}'**
  String continueFromPage(int page);

  /// No description provided for @lastSessionPage.
  ///
  /// In fr, this message translates to:
  /// **'Dernière session — page {page}'**
  String lastSessionPage(int page);

  /// No description provided for @pagesProgress.
  ///
  /// In fr, this message translates to:
  /// **'{current} / {total} pages'**
  String pagesProgress(int current, int total);

  /// No description provided for @noPreviousSession.
  ///
  /// In fr, this message translates to:
  /// **'Première session'**
  String get noPreviousSession;

  /// No description provided for @sharedByUser.
  ///
  /// In fr, this message translates to:
  /// **'Partagé par {name}'**
  String sharedByUser(String name);

  /// No description provided for @sessionAnnotations.
  ///
  /// In fr, this message translates to:
  /// **'Annotations de la session'**
  String get sessionAnnotations;

  /// No description provided for @annotateButton.
  ///
  /// In fr, this message translates to:
  /// **'Annoter'**
  String get annotateButton;

  /// No description provided for @comments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get comments;

  /// No description provided for @writeComment.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un commentaire...'**
  String get writeComment;

  /// No description provided for @commentBeingValidated.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire en cours de validation...'**
  String get commentBeingValidated;

  /// No description provided for @commentPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get commentPending;

  /// No description provided for @noCommentsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire pour le moment'**
  String get noCommentsYet;

  /// No description provided for @beFirstToComment.
  ///
  /// In fr, this message translates to:
  /// **'Sois le premier à commenter !'**
  String get beFirstToComment;

  /// No description provided for @send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get send;

  /// No description provided for @reactionPremiumOnly.
  ///
  /// In fr, this message translates to:
  /// **'Réaction réservée aux membres Premium'**
  String get reactionPremiumOnly;

  /// No description provided for @nearbyBookstores.
  ///
  /// In fr, this message translates to:
  /// **'Librairies proches'**
  String get nearbyBookstores;

  /// No description provided for @noBookstoresFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucune librairie trouvée à proximité'**
  String get noBookstoresFound;

  /// No description provided for @openNow.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get openNow;

  /// No description provided for @closed.
  ///
  /// In fr, this message translates to:
  /// **'Fermé'**
  String get closed;

  /// No description provided for @navigate.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get navigate;

  /// No description provided for @searchingBookstores.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de librairies...'**
  String get searchingBookstores;

  /// No description provided for @loadMoreBookstores.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus de librairies'**
  String get loadMoreBookstores;

  /// No description provided for @offlineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — les sessions seront synchronisées automatiquement'**
  String get offlineBanner;

  /// No description provided for @sessionSavedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Session enregistrée hors ligne. Elle sera synchronisée à la reconnexion.'**
  String get sessionSavedOffline;

  /// No description provided for @offlineSyncSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 session synchronisée} other{{count} sessions synchronisées}}'**
  String offlineSyncSuccess(int count);

  /// No description provided for @markAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout lire'**
  String get markAllRead;

  /// No description provided for @newNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles'**
  String get newNotifications;

  /// No description provided for @recentNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Récentes'**
  String get recentNotifications;

  /// No description provided for @noNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get noNotifications;

  /// No description provided for @noNotificationsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tu seras notifié des likes, commentaires et demandes d\'amis'**
  String get noNotificationsDesc;

  /// No description provided for @notifTypeFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get notifTypeFriends;

  /// No description provided for @notifTypeLike.
  ///
  /// In fr, this message translates to:
  /// **'Like'**
  String get notifTypeLike;

  /// No description provided for @notifTypeComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire'**
  String get notifTypeComment;

  /// No description provided for @notifTypeClub.
  ///
  /// In fr, this message translates to:
  /// **'Club'**
  String get notifTypeClub;

  /// No description provided for @accept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get accept;

  /// No description provided for @ignore.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get ignore;

  /// No description provided for @sentYouFriendRequest.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a envoyé une demande d\'ami'**
  String sentYouFriendRequest(String name);

  /// No description provided for @sentGroupJoinRequest.
  ///
  /// In fr, this message translates to:
  /// **'{name} souhaite rejoindre {groupName}'**
  String sentGroupJoinRequest(String name, String groupName);

  /// No description provided for @likedYourReading.
  ///
  /// In fr, this message translates to:
  /// **'{name} a aimé votre lecture de {bookTitle}'**
  String likedYourReading(String name, String bookTitle);

  /// No description provided for @commentedYourReading.
  ///
  /// In fr, this message translates to:
  /// **'{name} a commenté votre lecture de {bookTitle}'**
  String commentedYourReading(String name, String bookTitle);

  /// No description provided for @prizeSelections.
  ///
  /// In fr, this message translates to:
  /// **'Sélections LexDay'**
  String get prizeSelections;

  /// No description provided for @prizeSelectionsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Prix littéraires officiels'**
  String get prizeSelectionsSubtitle;

  /// No description provided for @officialLexDay.
  ///
  /// In fr, this message translates to:
  /// **'Officielle LexDay'**
  String get officialLexDay;

  /// No description provided for @bookSummary.
  ///
  /// In fr, this message translates to:
  /// **'Résumé du livre'**
  String get bookSummary;

  /// No description provided for @noDescriptionAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résumé disponible pour ce livre.'**
  String get noDescriptionAvailable;

  /// No description provided for @buyOnAmazon.
  ///
  /// In fr, this message translates to:
  /// **'Acheter sur Amazon'**
  String get buyOnAmazon;

  /// No description provided for @requestToJoin.
  ///
  /// In fr, this message translates to:
  /// **'Demander à rejoindre'**
  String get requestToJoin;

  /// No description provided for @joinRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée !'**
  String get joinRequestSent;

  /// No description provided for @joinRequestPending.
  ///
  /// In fr, this message translates to:
  /// **'Demande en attente…'**
  String get joinRequestPending;

  /// No description provided for @joinRequestCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Demande annulée'**
  String get joinRequestCancelled;

  /// No description provided for @joinRequestAccepted.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été accepté(e) dans le club'**
  String joinRequestAccepted(String name);

  /// No description provided for @joinRequestRejected.
  ///
  /// In fr, this message translates to:
  /// **'Demande de {name} refusée'**
  String joinRequestRejected(String name);

  /// No description provided for @pendingJoinRequests.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 demande en attente} other{{count} demandes en attente}}'**
  String pendingJoinRequests(int count);

  /// No description provided for @reject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get reject;

  /// No description provided for @readingForLabel.
  ///
  /// In fr, this message translates to:
  /// **'JE LIS POUR'**
  String get readingForLabel;

  /// No description provided for @readingForJustMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get readingForJustMe;

  /// No description provided for @readingForDaughter.
  ///
  /// In fr, this message translates to:
  /// **'Ma fille'**
  String get readingForDaughter;

  /// No description provided for @readingForSon.
  ///
  /// In fr, this message translates to:
  /// **'Mon fils'**
  String get readingForSon;

  /// No description provided for @readingForFriend.
  ///
  /// In fr, this message translates to:
  /// **'Un(e) ami(e)'**
  String get readingForFriend;

  /// No description provided for @readingForGrandmother.
  ///
  /// In fr, this message translates to:
  /// **'Ma grand-mère'**
  String get readingForGrandmother;

  /// No description provided for @readingForGrandfather.
  ///
  /// In fr, this message translates to:
  /// **'Mon grand-père'**
  String get readingForGrandfather;

  /// No description provided for @readingForPartner.
  ///
  /// In fr, this message translates to:
  /// **'Mon/Ma partenaire'**
  String get readingForPartner;

  /// No description provided for @readingForFather.
  ///
  /// In fr, this message translates to:
  /// **'Mon père'**
  String get readingForFather;

  /// No description provided for @readingForMother.
  ///
  /// In fr, this message translates to:
  /// **'Ma mère'**
  String get readingForMother;

  /// No description provided for @readingForOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get readingForOther;

  /// No description provided for @readingForDisplay.
  ///
  /// In fr, this message translates to:
  /// **'Lu pour {person}'**
  String readingForDisplay(String person);

  /// No description provided for @readingForStatsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lectures partagées'**
  String get readingForStatsTitle;

  /// No description provided for @readingForStatsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Temps passé à lire pour vos proches'**
  String get readingForStatsSubtitle;

  /// No description provided for @readingForNoStats.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'\'avez pas encore de session de lecture pour {person}'**
  String readingForNoStats(String person);

  /// No description provided for @readingForSessions.
  ///
  /// In fr, this message translates to:
  /// **'{count} sessions'**
  String readingForSessions(int count);

  /// No description provided for @readingForMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String readingForMinutes(int minutes);

  /// No description provided for @readingForPages.
  ///
  /// In fr, this message translates to:
  /// **'{pages} pages'**
  String readingForPages(int pages);

  /// No description provided for @refreshCovers.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser les couvertures'**
  String get refreshCovers;

  /// No description provided for @refreshingCovers.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation en cours…'**
  String get refreshingCovers;

  /// No description provided for @coversRefreshed.
  ///
  /// In fr, this message translates to:
  /// **'{count} couverture(s) mise(s) à jour'**
  String coversRefreshed(int count);

  /// No description provided for @coversUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les couvertures sont déjà à jour'**
  String get coversUpToDate;

  /// No description provided for @friendsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get friendsLabel;

  /// No description provided for @kindleLoginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion Kindle'**
  String get kindleLoginTitle;

  /// No description provided for @kindleTrustBanner.
  ///
  /// In fr, this message translates to:
  /// **'Connexion directe à Amazon. Tes identifiants ne transitent jamais par LexDay.'**
  String get kindleTrustBanner;

  /// No description provided for @kindleBooksFound.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{livre trouvé} other{livres trouvés}}'**
  String kindleBooksFound(int count);

  /// No description provided for @kindleStepLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Livres'**
  String get kindleStepLibrary;

  /// No description provided for @kindleStepInsights.
  ///
  /// In fr, this message translates to:
  /// **'Stats'**
  String get kindleStepInsights;

  /// No description provided for @kindleStepImport.
  ///
  /// In fr, this message translates to:
  /// **'Import'**
  String get kindleStepImport;

  /// No description provided for @kindlePhaseLoginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi à Amazon'**
  String get kindlePhaseLoginTitle;

  /// No description provided for @kindlePhaseLoginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes identifiants restent sur Amazon,\nnous n\'y avons jamais accès.'**
  String get kindlePhaseLoginSubtitle;

  /// No description provided for @kindlePhaseConnectingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion réussie !'**
  String get kindlePhaseConnectingTitle;

  /// No description provided for @kindlePhaseConnectingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Redirection vers ta bibliothèque…'**
  String get kindlePhaseConnectingSubtitle;

  /// No description provided for @kindlePhaseLibraryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récupération de tes livres…'**
  String get kindlePhaseLibraryTitle;

  /// No description provided for @kindlePhaseLibrarySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'On parcourt ta bibliothèque Kindle.'**
  String get kindlePhaseLibrarySubtitle;

  /// No description provided for @kindlePhaseInsightsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Analyse de tes habitudes…'**
  String get kindlePhaseInsightsTitle;

  /// No description provided for @kindlePhaseInsightsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'On récupère tes statistiques de lecture.'**
  String get kindlePhaseInsightsSubtitle;

  /// No description provided for @kindlePhaseImportingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours…'**
  String get kindlePhaseImportingTitle;

  /// No description provided for @kindlePhaseImportingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tes livres arrivent dans ta bibliothèque LexDay.'**
  String get kindlePhaseImportingSubtitle;

  /// No description provided for @kindlePhaseDoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'C\'est tout bon !'**
  String get kindlePhaseDoneTitle;

  /// No description provided for @kindlePhaseDoneSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ta bibliothèque Kindle est synchronisée.'**
  String get kindlePhaseDoneSubtitle;

  /// No description provided for @kindleOnboardingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connecte ton Kindle'**
  String get kindleOnboardingTitle;

  /// No description provided for @kindleOnboardingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Importe automatiquement ta bibliothèque Kindle.\nTes identifiants restent sur Amazon,\nnous n\'y avons jamais accès.'**
  String get kindleOnboardingSubtitle;

  /// No description provided for @kindleOnboardingButton.
  ///
  /// In fr, this message translates to:
  /// **'Connecter mon Kindle'**
  String get kindleOnboardingButton;

  /// No description provided for @kindleOnboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer cette étape'**
  String get kindleOnboardingSkip;

  /// No description provided for @kindlePhaseErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'La synchronisation a pris trop de temps'**
  String get kindlePhaseErrorTitle;

  /// No description provided for @kindlePhaseErrorSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Amazon n\'a pas répondu à temps.\nTu peux réessayer, ça prend généralement quelques secondes.'**
  String get kindlePhaseErrorSubtitle;

  /// No description provided for @kindleRetryButton.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get kindleRetryButton;

  /// No description provided for @premiumFeature.
  ///
  /// In fr, this message translates to:
  /// **'Fonctionnalité Premium'**
  String get premiumFeature;

  /// No description provided for @unlockFeatureWith.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer avec Premium'**
  String get unlockFeatureWith;

  /// No description provided for @premiumUpsellCta.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir Premium'**
  String get premiumUpsellCta;

  /// No description provided for @billingIssueTitle.
  ///
  /// In fr, this message translates to:
  /// **'Problème de paiement'**
  String get billingIssueTitle;

  /// No description provided for @billingIssueSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ton moyen de paiement pour continuer'**
  String get billingIssueSubtitle;

  /// No description provided for @savingsPercent.
  ///
  /// In fr, this message translates to:
  /// **'Économisez {percent}%'**
  String savingsPercent(int percent);

  /// No description provided for @trialBadge.
  ///
  /// In fr, this message translates to:
  /// **'7 jours gratuits'**
  String get trialBadge;

  /// No description provided for @perMonth.
  ///
  /// In fr, this message translates to:
  /// **'/mois'**
  String get perMonth;

  /// No description provided for @thenPerYear.
  ///
  /// In fr, this message translates to:
  /// **'puis {price}/an'**
  String thenPerYear(String price);

  /// No description provided for @noCommitment.
  ///
  /// In fr, this message translates to:
  /// **'Sans engagement'**
  String get noCommitment;

  /// No description provided for @recommended.
  ///
  /// In fr, this message translates to:
  /// **'✦ Recommandé'**
  String get recommended;

  /// No description provided for @freeIncludedSessions.
  ///
  /// In fr, this message translates to:
  /// **'Sessions illimitées'**
  String get freeIncludedSessions;

  /// No description provided for @freeIncludedLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Bibliothèque illimitée'**
  String get freeIncludedLibrary;

  /// No description provided for @freeIncludedFeed.
  ///
  /// In fr, this message translates to:
  /// **'Feed social'**
  String get freeIncludedFeed;

  /// No description provided for @freeIncludedGoals.
  ///
  /// In fr, this message translates to:
  /// **'Objectifs & badges de base'**
  String get freeIncludedGoals;

  /// No description provided for @freeIncludedWrapped.
  ///
  /// In fr, this message translates to:
  /// **'Wrapped mensuel & annuel'**
  String get freeIncludedWrapped;

  /// No description provided for @freeIncludedWidget.
  ///
  /// In fr, this message translates to:
  /// **'Widget iOS'**
  String get freeIncludedWidget;

  /// No description provided for @fabTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer une lecture'**
  String get fabTooltip;

  /// No description provided for @shareMySession.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma session'**
  String get shareMySession;

  /// No description provided for @saveImage.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer l\'image'**
  String get saveImage;

  /// No description provided for @imageSaved.
  ///
  /// In fr, this message translates to:
  /// **'Image enregistrée'**
  String get imageSaved;

  /// No description provided for @staleSessionModalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session en cours'**
  String get staleSessionModalTitle;

  /// No description provided for @staleSessionModalBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu as une session de lecture active. Tu as fini de lire ?'**
  String get staleSessionModalBody;

  /// No description provided for @staleSessionFinishButton.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get staleSessionFinishButton;

  /// No description provided for @staleSessionContinueButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get staleSessionContinueButton;

  /// No description provided for @staleSessionNotifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session de lecture en cours'**
  String get staleSessionNotifTitle;

  /// No description provided for @staleSessionNotifBody.
  ///
  /// In fr, this message translates to:
  /// **'Tu as laissé une session de lecture ouverte. Tu as fini ?'**
  String get staleSessionNotifBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
