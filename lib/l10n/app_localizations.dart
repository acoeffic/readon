import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  /// **'🔐 Politique de confidentialité'**
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
