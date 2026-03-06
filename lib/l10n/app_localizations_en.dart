// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navFeed => 'Feed';

  @override
  String get navLibrary => 'Library';

  @override
  String get navClub => 'Club';

  @override
  String get navProfile => 'My space';

  @override
  String get kindleSyncedAutomatically => 'Kindle synced automatically';

  @override
  String get enterEmailToReset => 'Enter your email to reset';

  @override
  String get emailSentCheckInbox => 'Email sent, check your inbox.';

  @override
  String get errorSendingEmail => 'Error sending email';

  @override
  String tooManyAttemptsRetryIn(int seconds) {
    return 'Too many attempts. Retry in ${seconds}s';
  }

  @override
  String get emailAndPasswordRequired => 'Email and password required';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get errorSignInApple => 'Error signing in with Apple';

  @override
  String get errorSignInGoogle => 'Error signing in with Google';

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
  String get emailAlreadyUsed => 'Email already in use';

  @override
  String get emailAlreadyUsedMessage =>
      'This email is already associated with an existing account. Would you like to reset your password?';

  @override
  String get back => 'Back';

  @override
  String get reset => 'Reset';

  @override
  String get resetEmailSent => 'Reset email sent. Check your inbox.';

  @override
  String get passwordMin8Chars => 'Password must be at least 8 characters';

  @override
  String get passwordRequirements =>
      'Password must contain uppercase, lowercase and a number';

  @override
  String get mustAcceptTerms => 'You must accept the terms of use';

  @override
  String get accountCreatedCheckEmail => 'Account created, check your emails.';

  @override
  String get createAccountTitle => 'Create an account';

  @override
  String get joinLexDay => 'Join LexDay';

  @override
  String get enterInfoToStart => 'Enter your information to start reading';

  @override
  String get name => 'Name';

  @override
  String get yourName => 'Your name';

  @override
  String get yourEmail => 'your.email@mail.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get createAccount => 'Create an account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get legalNotices => 'Legal notices';

  @override
  String get emailSent => 'Email sent';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get confirmEmailSent =>
      'We sent you a link to confirm your email address.';

  @override
  String get iConfirmedMyEmail => 'I confirmed my email';

  @override
  String get suggestionsForYou => 'Suggestions for you';

  @override
  String bookAddedToLibrary(String title) {
    return '$title added to your library';
  }

  @override
  String get errorAddingBook => 'Error adding book';

  @override
  String get recentSessions => 'Recent sessions';

  @override
  String get recentBadges => 'Recent badges';

  @override
  String get friendsActivity => 'Your friends\' activity';

  @override
  String get refresh => 'Refresh';

  @override
  String get friendsNotReadToday => 'Your friends haven\'t read today yet';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get addFriendsToSeeActivity => 'Add friends to see their reading!';

  @override
  String get shareInviteText =>
      '📖 Join me on LexDay!\n\nWhat are you reading? 👀\nlexday.app';

  @override
  String errorGeneric(String message) {
    return 'Error: $message';
  }

  @override
  String get myLibrary => 'My Library';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get searchBook => 'Search a book...';

  @override
  String get statusLabel => 'Status';

  @override
  String get genreLabel => 'Genre';

  @override
  String get noBooksInLibrary => 'No books in your library';

  @override
  String get scanOrSyncBooks => 'Scan a cover or sync your Kindle books';

  @override
  String authorFoundForBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Author found for $count book$_temp0';
  }

  @override
  String get noAuthorFound => 'No author found';

  @override
  String get errorSearchingAuthors => 'Error searching for authors';

  @override
  String get searchingInProgress => 'Searching...';

  @override
  String get searchMissingAuthors => 'Search for missing authors';

  @override
  String get settings => 'Settings';

  @override
  String get profileSection => 'Profile';

  @override
  String get editName => '✏️ Edit name';

  @override
  String get uploadingPhoto => '📸 Uploading...';

  @override
  String get changeProfilePicture => '📸 Change profile picture';

  @override
  String get subscriptionSection => 'Subscription';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get freeTrial => 'Free trial';

  @override
  String freeTrialUntil(String date) {
    return 'Free trial (until $date)';
  }

  @override
  String get premiumActive => 'Premium active';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium active (until $date)';
  }

  @override
  String get privacySection => 'Privacy';

  @override
  String get privateProfile => '🔒 Private profile';

  @override
  String get statsHidden => 'Your stats are hidden';

  @override
  String get statsPublic => 'Your stats are public';

  @override
  String get privateProfileInfoOn =>
      'Other users will only see your name and profile picture.';

  @override
  String get privateProfileInfoOff =>
      'Other users can see your badges, books, flow and statistics.';

  @override
  String get hideReadingHours => '⏱️ Hide reading hours';

  @override
  String get readingHoursHidden => 'Your reading hours are hidden';

  @override
  String get readingHoursVisible => 'Your reading hours are visible';

  @override
  String get readingHoursInfo =>
      'Other users won\'t see your total reading time.';

  @override
  String get profilePrivateEnabled =>
      'Private profile enabled. Only your friends will see your stats.';

  @override
  String get profilePublicEnabled =>
      'Public profile enabled. Everyone can see your stats.';

  @override
  String get readingHoursHiddenSnack => 'Reading hours hidden.';

  @override
  String get readingHoursVisibleSnack => 'Reading hours visible.';

  @override
  String get readingSection => 'Reading';

  @override
  String get editReadingGoal => '🎯 Edit reading goal';

  @override
  String get flowNotifications => '🔔 Flow notifications';

  @override
  String get kindleSection => 'Kindle';

  @override
  String get resyncKindle => '📚 Resync Kindle';

  @override
  String get connectKindle => '📚 Connect Kindle';

  @override
  String lastSync(String date) {
    return '✅ Last sync: $date';
  }

  @override
  String get autoSync => 'Auto sync';

  @override
  String get kindleAutoSyncDescription =>
      'Sync your Kindle books at each app launch';

  @override
  String get kindleSyncedSuccess => 'Kindle synced successfully!';

  @override
  String get notionSection => 'Notion';

  @override
  String connectedTo(String name) {
    return 'Connected to $name';
  }

  @override
  String get notionSheetsDescription =>
      'Your reading sheets can be sent to Notion';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connectNotion => '📝 Connect Notion';

  @override
  String get notionSyncDescription =>
      'Sync your AI reading sheets to a Notion database';

  @override
  String get disconnectNotionTitle => 'Disconnect Notion?';

  @override
  String get disconnectNotionMessage =>
      'Your already synced sheets will remain in Notion.';

  @override
  String get notionDisconnected => 'Notion disconnected';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get lightTheme => '🌞 Light theme';

  @override
  String get lightThemeActive => '🌞 Light theme (active)';

  @override
  String get darkTheme => '🌙 Dark theme';

  @override
  String get darkThemeActive => '🌙 Dark theme (active)';

  @override
  String get languageSection => 'Language';

  @override
  String get frenchActive => '🇫🇷 Français (actif)';

  @override
  String get french => '🇫🇷 Français';

  @override
  String get english => '🇬🇧 English';

  @override
  String get englishActive => '🇬🇧 English (active)';

  @override
  String get accountSection => 'Account';

  @override
  String get manageConnections => '🖥️ Manage connections & devices';

  @override
  String get legalSection => 'Legal';

  @override
  String get termsOfService => '📜 Terms of service';

  @override
  String get privacyPolicy => '🔐 Privacy policy';

  @override
  String get legalNoticesItem => '⚖️ Legal notices';

  @override
  String get logoutTitle => 'Sign out?';

  @override
  String get logoutMessage => 'You will be signed out. Continue?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get logout => '❌ Sign out';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get deleteAccountWarning => 'Account deletion is irreversible.';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountMessage =>
      'This action is irreversible. All your data (books, reading sessions, badges, friends, groups) will be permanently deleted.';

  @override
  String get continueButton => 'Continue';

  @override
  String get confirmDeletion => 'Confirm deletion';

  @override
  String get typeDeleteToConfirm => 'To confirm, type DELETE below:';

  @override
  String get deleteKeyword => 'DELETE';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String errorDeletingAccount(String error) {
    return 'Error deleting account: $error';
  }

  @override
  String get editNameTitle => 'Edit name';

  @override
  String get displayName => 'Display name';

  @override
  String get save => 'Save';

  @override
  String get nameMinLength => 'Name must be at least 2 characters';

  @override
  String get nameMaxLength => 'Name must not exceed 50 characters';

  @override
  String get nameUpdated => 'Name updated!';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get imageTooLarge => 'Image too large. Maximum size: 5MB';

  @override
  String get unsupportedFormat => 'Unsupported format. Use JPG, PNG or WebP';

  @override
  String get notConnected => 'Not connected';

  @override
  String get profilePictureUpdated => '✅ Profile picture updated!';

  @override
  String timeAgoMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeAgoDays(int days) {
    return '${days}d ago';
  }

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get sessionAbandoned => 'Session abandoned';

  @override
  String get muse => '💡 Muse';

  @override
  String get newBook => 'New book';

  @override
  String get myLibraryFab => 'My library';

  @override
  String get searchEllipsis => 'Search...';

  @override
  String get noBookFound => 'No book found';

  @override
  String get abandonSessionTitle => 'Abandon session';

  @override
  String get abandonSessionMessage =>
      'Do you really want to abandon this reading session?';

  @override
  String get no => 'No';

  @override
  String get yes => 'Yes';

  @override
  String get leaveSessionTitle => 'Leave session';

  @override
  String get leaveSessionMessage =>
      'The session stays active. You can finish it later.';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get sessionInProgress => 'SESSION IN PROGRESS';

  @override
  String get cancelSessionTitle => 'Cancel session';

  @override
  String get cancelSessionMessage =>
      'Are you sure you want to cancel this reading session?';

  @override
  String errorCapture(String error) {
    return 'Error during capture: $error';
  }

  @override
  String get errorGoogleBooks => 'Google Books search error';

  @override
  String get termsOfServiceTitle => 'Terms of Service';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get legalNoticesTitle => 'Legal Notices';

  @override
  String get iAcceptTerms => 'I accept the terms';
}
