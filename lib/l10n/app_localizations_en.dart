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
  String get systemTheme => '📱 System';

  @override
  String get systemThemeActive => '📱 System (active)';

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
  String get spanish => '🇪🇸 Español';

  @override
  String get spanishActive => '🇪🇸 Español (active)';

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

  @override
  String get sessionDuration => 'SESSION DURATION';

  @override
  String get startPage => 'Start page';

  @override
  String get streakLabel => 'Streak';

  @override
  String streakDays(int days) {
    return '$days days';
  }

  @override
  String get endSessionSlide => 'End session';

  @override
  String get abandonButton => 'Abandon';

  @override
  String get newAnnotation => 'New annotation';

  @override
  String get annotationText => 'Text';

  @override
  String get annotationPhoto => 'Photo';

  @override
  String get annotationVoice => 'Voice';

  @override
  String get retakePhoto => 'Retake photo';

  @override
  String get extractingText => 'Extracting text...';

  @override
  String get micPermissionRequired => 'Microphone permission required';

  @override
  String get tapToRecord => 'Tap to record';

  @override
  String get recordingInProgress => 'Recording in progress...';

  @override
  String get retakeRecording => 'Redo';

  @override
  String get transcriptionInProgress => 'Transcription in progress...';

  @override
  String get hintExtractedText => 'Extracted text (editable)...';

  @override
  String get hintTranscription => 'Transcription (editable)...';

  @override
  String get hintAnnotation => 'Write a thought, a quote...';

  @override
  String get voiceAnnotationSaved => 'Voice annotation saved!';

  @override
  String get annotationSaved => 'Annotation saved!';

  @override
  String get transcribing => 'Transcribing...';

  @override
  String get pageHint => 'Page';

  @override
  String errorSelection(String error) {
    return 'Error during selection: $error';
  }

  @override
  String get pageNotDetected => 'Page number not detected. Enter it manually.';

  @override
  String get pageNotDetectedManual =>
      'Page number not detected. You can enter it manually below.';

  @override
  String endPageBeforeStartDetailed(int endPage, int startPage) {
    return 'End page ($endPage) cannot be before start page ($startPage).';
  }

  @override
  String ocrError(String error) {
    return 'OCR error: $error';
  }

  @override
  String get invalidPageNumber => 'Please enter a valid page number.';

  @override
  String get captureOrEnterPage =>
      'Please take a photo or enter a page number.';

  @override
  String get endPageBeforeStart => 'End page cannot be before start page.';

  @override
  String get finishBookTitle => 'Finish book';

  @override
  String get finishBookConfirm =>
      'Congratulations! Have you finished this book?';

  @override
  String get yesFinished => 'Yes, finished!';

  @override
  String get endReading => 'End reading';

  @override
  String get currentSession => 'Current session';

  @override
  String startedAtPage(int page) {
    return 'Started at page $page';
  }

  @override
  String durationValue(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get instructions => 'Instructions';

  @override
  String get instructionEndPhoto => '1. Take a photo of your last page read';

  @override
  String get instructionEndVisible => '2. Make sure the number is visible';

  @override
  String get instructionEndValidate => '3. Confirm to save your progress';

  @override
  String get instructionStartPhoto =>
      '1. Take a photo of the page where you start';

  @override
  String get instructionStartVisible =>
      '2. Make sure the page number is visible';

  @override
  String get instructionStartOcr =>
      '3. OCR will automatically detect the number';

  @override
  String get takePhotoBtn => 'Take Photo';

  @override
  String get galleryBtn => 'Gallery';

  @override
  String get analyzing => 'Analyzing...';

  @override
  String get photoCaptured => 'Photo captured:';

  @override
  String get pageCorrected => 'Page corrected:';

  @override
  String get pageDetected => 'Page detected:';

  @override
  String pagesReadCount(int count) {
    return 'Pages read: $count';
  }

  @override
  String get correctNumber => 'Correct the number';

  @override
  String get pageNumberLabel => 'Page number';

  @override
  String startPagePrefix(int page) {
    return 'Start page: $page';
  }

  @override
  String get validate => 'Confirm';

  @override
  String get orEnterManually => 'Or enter the number directly:';

  @override
  String get startReadingTitle => 'Start a reading session';

  @override
  String get sessionAlreadyActive => 'A session is already in progress';

  @override
  String get resumeSession => 'Resume session';

  @override
  String get startReadingSession => 'Start reading session';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get bookFinishedExcl => 'Book finished!';

  @override
  String get continueExcl => 'Continue!';

  @override
  String get flowBadgeTitle => 'Flow Badge!';

  @override
  String consecutiveDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$days consecutive day$_temp0!';
  }

  @override
  String museBookFinished(String title) {
    return 'Well done on $title! Want Muse to suggest your next read?';
  }

  @override
  String get later => 'Later';

  @override
  String get chatWithMuse => 'Chat with Muse';

  @override
  String get defaultUser => 'User';

  @override
  String get mySessions => 'My Sessions';

  @override
  String get myStatistics => 'Statistics';

  @override
  String get myLists => 'My Lists';

  @override
  String get statistics => 'Statistics';

  @override
  String get readingStatistics => 'Reading statistics';

  @override
  String get featureComingSoon => 'Feature coming soon';

  @override
  String get cannotAddBook => 'Cannot add this book';

  @override
  String get titleAuthorPagesRequired => 'Title, author and pages required';

  @override
  String get bookAdded => 'Book added';

  @override
  String get errorAdding => 'Error adding book';

  @override
  String get addBookTitle => 'Add a book';

  @override
  String get googleBooksSearchTitle => 'Google Books search';

  @override
  String get titleAuthorIsbn => 'Title, author or ISBN';

  @override
  String get noTitleDefault => 'No title';

  @override
  String get addButton => 'Add';

  @override
  String get manualAdd => 'Manual add';

  @override
  String get titleHint => 'Title';

  @override
  String get authorHint => 'Author';

  @override
  String get totalPages => 'Total pages';

  @override
  String get activeSessionDialogTitle => 'Active session';

  @override
  String get activeSessionDialogMessage =>
      'A reading session is already in progress for this book.';

  @override
  String pageAtNumber(int page) {
    return 'Page $page';
  }

  @override
  String get whatDoYouWant => 'What would you like to do?';

  @override
  String get resume => 'Resume';

  @override
  String get sessionCompleted => 'SESSION COMPLETED';

  @override
  String get sessionCompletedTitle => 'Session completed!';

  @override
  String get myReadingDefault => 'My reading';

  @override
  String get durationStatLabel => 'duration';

  @override
  String get pagesReadStatLabel => 'pages read';

  @override
  String get streakStatLabel => 'streak';

  @override
  String streakDaysShort(int days) {
    return '$days d.';
  }

  @override
  String get readingPace => 'Reading pace';

  @override
  String get avgTimePerPage => 'Avg. time per page';

  @override
  String get estimatedBookEnd => 'Estimated book end';

  @override
  String get vsYourAverage => 'vs. your average';

  @override
  String fasterPercent(int percent) {
    return '+$percent% faster';
  }

  @override
  String slowerPercent(int percent) {
    return '$percent% slower';
  }

  @override
  String get withinAverage => 'Within your average';

  @override
  String get sessionInsights => 'Session insights';

  @override
  String get viewFullReport => '✨ View full report';

  @override
  String get paceAndTrends => 'Pace, trends, estimated end and more';

  @override
  String get tryPremium => 'Try';

  @override
  String get shareSession => 'Share session';

  @override
  String get hideSession => 'Hide this session';

  @override
  String get sessionHiddenFromRankings => 'Session hidden from rankings';

  @override
  String get errorHidingSession => 'Error hiding session';

  @override
  String get skip => 'Skip';

  @override
  String nPages(int count) {
    return '$count pages';
  }

  @override
  String get bookCompletedHeader => 'BOOK COMPLETED';

  @override
  String get bookCompletedTitle => 'Book completed!';

  @override
  String get congratsFinished => 'Congratulations, you\'ve finished';

  @override
  String get completed => 'Completed';

  @override
  String get ofReading => 'of reading';

  @override
  String get sessions => 'sessions';

  @override
  String readingDaysCount(int count) {
    return '$count reading days';
  }

  @override
  String get bookReport => 'Book report';

  @override
  String get avgPace => 'Average pace';

  @override
  String get preferredSlot => 'Preferred time slot';

  @override
  String get bestSession => 'Best session';

  @override
  String get readingRegularity => 'Reading regularity';

  @override
  String get morningSlot => 'Morning (6am–12pm)';

  @override
  String get afternoonSlot => 'Afternoon (12pm–6pm)';

  @override
  String get eveningSlot => 'Evening (6pm–10pm)';

  @override
  String get nightSlot => 'Night (10pm–6am)';

  @override
  String get unknownSlot => 'Unknown';

  @override
  String pagesInDuration(int pages, String duration) {
    return '$pages pages in $duration';
  }

  @override
  String daysPerWeek(String count) {
    return '$count d/wk';
  }

  @override
  String get unlockedBadges => 'Unlocked badges';

  @override
  String get share => 'Share';

  @override
  String get backToHome => 'Back to home';

  @override
  String get paceAndSlots => 'Pace, time slots, regularity and more';

  @override
  String get clubSubtitle => 'community';

  @override
  String get readingClubs => 'Reading Clubs';

  @override
  String get readingClub => 'Reading Club';

  @override
  String get myClubs => 'My clubs';

  @override
  String get myGroups => 'My groups';

  @override
  String get discover => 'Discover';

  @override
  String get createClub => 'Create a Club';

  @override
  String get noGroups => 'No groups';

  @override
  String get createOrJoinGroup => 'Create or join a reading group';

  @override
  String get noPublicGroups => 'No public groups';

  @override
  String get beFirstToCreate => 'Be the first to create a public group!';

  @override
  String get privateTag => 'Private';

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
    return '$count member$_temp0';
  }

  @override
  String byCreator(String name) {
    return 'by $name';
  }

  @override
  String get limitReached => 'Limit reached';

  @override
  String groupLimitMessage(int max) {
    return 'You\'ve reached the limit of $max reading clubs. Upgrade to Premium to join as many as you want!';
  }

  @override
  String get becomePremium => 'Go Premium';

  @override
  String get leaveGroupTitle => 'Leave group?';

  @override
  String get leaveGroupMessage => 'Do you really want to leave this group?';

  @override
  String get leftGroup => 'You left the group';

  @override
  String get groupNotFound => 'Group not found';

  @override
  String get members => 'Members';

  @override
  String get activities => 'Activities';

  @override
  String get activeChallenges => 'Active challenges';

  @override
  String get createChallenge => 'Create a challenge';

  @override
  String get noChallengeActive => 'No active challenge';

  @override
  String get groupActivities => 'Group activities';

  @override
  String get noActivity => 'No activity';

  @override
  String get activitiesWillAppear => 'Member activities will appear here';

  @override
  String readPagesOf(int pages, String title) {
    return 'read $pages pages of \"$title\"';
  }

  @override
  String finishedBook(String title) {
    return 'finished \"$title\" 🎉';
  }

  @override
  String get joinedGroup => 'joined the group';

  @override
  String recommendsBook(String title) {
    return 'recommends \"$title\"';
  }

  @override
  String get unknownActivity => 'unknown activity';

  @override
  String get justNow => 'Just now';

  @override
  String get createGroupTitle => 'Create a group';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get groupNameRequired => 'Group name *';

  @override
  String get groupNameHint => 'E.g.: Sci-Fi Readers Club';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get describeGroup => 'Describe your reading group...';

  @override
  String get privateGroup => 'Private group';

  @override
  String get inviteOnly => 'Accessible by invitation only';

  @override
  String get visibleToAll => 'Visible to all users';

  @override
  String get creatorAdminInfo =>
      'As the creator, you will automatically be the group admin and can invite other members.';

  @override
  String get createGroup => 'Create group';

  @override
  String get groupCreated => 'Group created successfully!';

  @override
  String get allFriendsInGroup => 'All your friends are already group members';

  @override
  String get inviteFriend => 'Invite a friend';

  @override
  String invitationSent(String name) {
    return '✅ Invitation sent to $name';
  }

  @override
  String roleUpdated(String name) {
    return '$name\'s role updated';
  }

  @override
  String get removeFromGroupTitle => 'Remove from group?';

  @override
  String removeFromGroupMessage(String name) {
    return 'Do you want to remove $name from the group?';
  }

  @override
  String get removeButton => 'Remove';

  @override
  String memberRemoved(String name) {
    return '$name has been removed from the group';
  }

  @override
  String get demoteToMember => 'Demote to member';

  @override
  String get promoteAdmin => 'Promote to admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String membersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get noMembers => 'No members';

  @override
  String get youTag => 'You';

  @override
  String get administrator => 'Administrator';

  @override
  String get memberRole => 'Member';

  @override
  String get photoUpdated => 'Photo updated';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get deleteGroupTitle => 'Delete group?';

  @override
  String get deleteGroupMessage =>
      'This action is irreversible. All members will be removed and group data will be lost.';

  @override
  String get deleteButton => 'Delete';

  @override
  String get confirmDeleteGroupTitle => 'Confirm deletion';

  @override
  String confirmDeleteGroupMessage(String name) {
    return 'Do you really want to permanently delete \"$name\"?';
  }

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get currentReading => 'Current Reading';

  @override
  String get noCurrentReading => 'No current book';

  @override
  String get setCurrentReading => 'Set the group\'s current reading';

  @override
  String get inviteMembers => 'Invite members';

  @override
  String get changeImage => 'Change image';

  @override
  String get groupSettings => 'Group settings';

  @override
  String get groupPhoto => 'Group photo';

  @override
  String get information => 'Information';

  @override
  String get description => 'Description';

  @override
  String get visibility => 'Visibility';

  @override
  String get publicGroup => 'Public group';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get manageMembers => 'Manage members';

  @override
  String get manageMembersSubtitle => 'View, invite and manage roles';

  @override
  String get deleteChallengeTitle => 'Delete challenge?';

  @override
  String get deleteChallengeMessage => 'This action is irreversible.';

  @override
  String get challengeDeleted => 'Challenge deleted';

  @override
  String get expired => 'Expired';

  @override
  String daysRemaining(int days) {
    return '${days}d remaining';
  }

  @override
  String hoursRemaining(int hours) {
    return '${hours}h remaining';
  }

  @override
  String minutesRemaining(int minutes) {
    return '${minutes}min remaining';
  }

  @override
  String get readABook => 'Read a book';

  @override
  String pagesToRead(int count) {
    return '$count pages to read';
  }

  @override
  String dailyChallenge(int minutes, int days) {
    return '$minutes min/day for $days days';
  }

  @override
  String get challengeDetail => 'Challenge detail';

  @override
  String get leaveChallenge => 'Leave challenge';

  @override
  String get joinChallenge => 'Join challenge';

  @override
  String get leftChallenge => 'You left the challenge';

  @override
  String get joinedChallenge => 'You joined the challenge!';

  @override
  String participantsCount(int count) {
    return 'Participants ($count)';
  }

  @override
  String get noParticipants => 'No participants';

  @override
  String get challengeCompleted => 'Completed!';

  @override
  String get challengeInProgress => 'In progress...';

  @override
  String progressPages(int progress, int target) {
    return '$progress / $target pages';
  }

  @override
  String progressDays(int progress, int target) {
    return '$progress / $target days';
  }

  @override
  String get myProgress => 'My progress';

  @override
  String get completedTag => 'Completed';

  @override
  String get newChallenge => 'New challenge';

  @override
  String get challengeType => 'Challenge type';

  @override
  String get challengeTitleRequired => 'Challenge title *';

  @override
  String get challengeTitleHint => 'E.g.: Reading marathon';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get startDate => 'Start date';

  @override
  String get startsOn => 'Starts on';

  @override
  String get startsToday => 'Today';

  @override
  String get upcoming => 'Upcoming';

  @override
  String daysUntilStart(int days) {
    return 'In ${days}d';
  }

  @override
  String get challengeStartNotifTitle => 'The challenge starts today!';

  @override
  String get deadline => 'Deadline';

  @override
  String get createChallengeBtn => 'Create challenge';

  @override
  String get challengeCreated => 'Challenge created!';

  @override
  String get pagesType => 'Pages';

  @override
  String get bookType => 'Book';

  @override
  String get dailyType => 'Daily';

  @override
  String get bookToRead => 'Book to read';

  @override
  String get goalLabel => 'Goal';

  @override
  String get pagesCountRequired => 'Number of pages *';

  @override
  String get pagesCountHint => 'E.g.: 200';

  @override
  String get pagesUnit => 'pages';

  @override
  String get required => 'Required';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get dailyGoal => 'Daily goal';

  @override
  String get dailyMinutesRequired => 'Reading minutes per day *';

  @override
  String get dailyMinutesHint => 'E.g.: 30';

  @override
  String get minPerDay => 'min/day';

  @override
  String get daysCountRequired => 'Number of days *';

  @override
  String get daysCountHint => 'E.g.: 7';

  @override
  String get daysUnit => 'days';

  @override
  String get oneWeek => '1 wk';

  @override
  String get twoWeeks => '2 wks';

  @override
  String get oneMonth => '1 month';

  @override
  String get expiresOn => 'Expires on';

  @override
  String get chooseBook => 'Choose a book';

  @override
  String get searchBookHint => 'Search a book...';

  @override
  String get noResult => 'No result';

  @override
  String get selectBookPrompt => 'Please select a book';

  @override
  String readBookTitle(String title) {
    return 'Read \"$title\"';
  }

  @override
  String get privateProfileLabel => 'Private profile';

  @override
  String privateProfileMessage(String name) {
    return 'This profile is private. Add $name as a friend to see their stats.';
  }

  @override
  String get books => 'Books';

  @override
  String get viewFullProfile => 'View full profile';

  @override
  String get followLabel => 'Add friend';

  @override
  String get pagesLabel => 'Pages';

  @override
  String get readingLabel => 'Reading';

  @override
  String get flowLabel => 'Flow';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get noRecentActivity => 'No recent activity';

  @override
  String get theirBadges => 'Their badges';

  @override
  String get removeFriend => 'Remove friend';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get addFriend => 'Add friend';

  @override
  String get removeFriendTitle => 'Remove this friend?';

  @override
  String removeFriendMessage(String name) {
    return 'Do you want to remove $name from your friends?';
  }

  @override
  String get requestSent => 'Request sent';

  @override
  String get requestCancelled => 'Request cancelled';

  @override
  String get friendRemoved => 'Friend removed';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get myFriends => 'My friends';

  @override
  String get findFriends => 'Find friends';

  @override
  String get retry => 'Retry';

  @override
  String get noFriendFound => 'No friend found';

  @override
  String get addFriendsToSeeActivityMessage =>
      'Add friends to see their activity!';

  @override
  String get friendRemovedSnack => 'Friend removed';

  @override
  String cannotRemoveFriend(String error) {
    return 'Cannot remove this friend: $error';
  }

  @override
  String get searchLabel => 'Search';

  @override
  String get friends => 'Friends';

  @override
  String get groups => 'Groups';

  @override
  String get searchByName => 'Search by name';

  @override
  String get groupName => 'Group name';

  @override
  String get inviteToRead => 'Invite your friends to read';

  @override
  String get shareWhatYouRead => 'Share what you\'re reading right now';

  @override
  String get typeMin2Chars => 'Type at least 2 characters to search';

  @override
  String get invitationSentShort => 'Invitation sent';

  @override
  String get cannotAddFriend => 'Cannot add this friend';

  @override
  String get cannotCancelRequest => 'Cannot cancel request';

  @override
  String relationAlreadyExists(String status) {
    return 'Relation already $status';
  }

  @override
  String get invalidUser => 'Invalid user';

  @override
  String get connectToAddFriend => 'Sign in to add a friend';

  @override
  String get errorDuringSearch => 'Error during search';

  @override
  String get firstSessionBravo => 'Well done on your first\nreading session!';

  @override
  String get friendsReadToo =>
      'Your friends read too.\nAdd them to see their activity!';

  @override
  String get findMyFriends => 'Find my friends';

  @override
  String get searchingContacts => 'Searching for your friends...';

  @override
  String get noContactOnLexDay => 'None of your contacts use LexDay yet';

  @override
  String friendsFoundOnLexDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count friend$_temp0 found on LexDay';
  }

  @override
  String get inviteFriendsToJoin => 'Invite your friends to join LexDay!';

  @override
  String get sent => 'Sent';

  @override
  String get contactsAccessDenied => 'Contacts access denied';

  @override
  String get cannotAccessContacts => 'Cannot access contacts';

  @override
  String get authorizeContactsSettings =>
      'To find your friends, allow access to contacts in Settings.';

  @override
  String get errorOccurredRetryLater => 'An error occurred. Try again later.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get findContactsFriends => 'Find friends';

  @override
  String get searchingYourContacts => 'Searching your contacts...';

  @override
  String get noContactFound => 'No contact found';

  @override
  String get contactsNotOnLexDay =>
      'Your contacts don\'t seem to use LexDay yet.';

  @override
  String get alreadyOnLexDay => 'Already on LexDay';

  @override
  String get inviteToLexDay => 'Invite to LexDay';

  @override
  String get invited => 'Invited';

  @override
  String get invite => 'Invite';

  @override
  String get authorizeContacts =>
      'To find your friends, allow access to your contacts.';

  @override
  String get cannotAccessContactsRetry =>
      'Cannot access your contacts. Try again later.';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get shareInviteToLexDay =>
      'Join me on LexDay to track our reading together! Download the app: https://readon.app';

  @override
  String get friendRequests => 'Friend requests';

  @override
  String get cannotGetRequests => 'Cannot get requests';

  @override
  String get friendAdded => 'Friend added';

  @override
  String get requestDeclined => 'Request declined';

  @override
  String get actionImpossible => 'Action impossible';

  @override
  String get noRequest => 'No requests';

  @override
  String get museGreeting =>
      'Hi, I\'m Muse, your reading advisor. What would you like to read?';

  @override
  String get museRecommendNovel => 'Recommend me a novel';

  @override
  String get museSimilarBook => 'A book similar to my last one';

  @override
  String get museClassic => 'A classic to discover';

  @override
  String freeMessagesUsed(int max) {
    return 'You\'ve used your $max free messages this month';
  }

  @override
  String get subscribeForUnlimited =>
      'Subscribe to chat with Muse without limits!';

  @override
  String get discoverSubscription => 'Discover subscription';

  @override
  String get askRecommendation => 'Ask for a recommendation...';

  @override
  String cannotLoadBook(String error) {
    return 'Cannot load book: $error';
  }

  @override
  String get inBookstore => 'In bookstore';

  @override
  String get findNearMe => 'Find near me';

  @override
  String get enableLocationSettings => 'Enable location in Settings';

  @override
  String get locationAccessRequired => 'Location access required';

  @override
  String get addToList => 'Add to a list';

  @override
  String get noPersonalList => 'No personal list.';

  @override
  String get createNewList => 'Create a new list';

  @override
  String addedToList(String title) {
    return 'Added to \"$title\"';
  }

  @override
  String get deleteConversation => 'Delete conversation';

  @override
  String get deleteConversationConfirm =>
      'Are you sure you want to delete this conversation?';

  @override
  String get unlimitedChatbot => 'Unlimited chatbot use, subscribe';

  @override
  String messagesUsedCount(int used, int max) {
    return '$used/$max messages used this month';
  }

  @override
  String get noConversation => 'No conversations';

  @override
  String get startConversationMuse =>
      'Start a conversation with Muse to get personalized book recommendations.';

  @override
  String get newConversation => 'New conversation';

  @override
  String get readingLists => 'Reading lists';

  @override
  String nBooks(int count) {
    return '$count books';
  }

  @override
  String nReaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count reader$_temp0';
  }

  @override
  String nRead(int read, int total) {
    return '$read/$total read';
  }

  @override
  String get deleteListTitle => 'Delete this list?';

  @override
  String deleteListMessage(String title) {
    return 'The list \"$title\" will be permanently deleted.';
  }

  @override
  String get editButton => 'Edit';

  @override
  String get addBookToList => 'Add a book';

  @override
  String get noBooksInList => 'No books in this list';

  @override
  String get addBooksFromLibrary =>
      'Add books from your library or by searching for a title.';

  @override
  String get removeBookTitle => 'Remove this book?';

  @override
  String removeBookMessage(String title) {
    return 'Remove \"$title\" from this list?';
  }

  @override
  String get removeFromLibraryTitle => 'Remove from my library?';

  @override
  String removeFromLibraryMessage(String title) {
    return 'Permanently remove \"$title\" from your library?';
  }

  @override
  String get removeFromLibraryAction => 'Remove';

  @override
  String get bookRemovedFromLibrary => 'Book removed from your library';

  @override
  String get myListsSection => 'My lists';

  @override
  String get savedLists => 'Saved lists';

  @override
  String get noList => 'No lists';

  @override
  String get createListCta =>
      'Create your own reading list or discover our curated selections.';

  @override
  String get createList => 'Create a list';

  @override
  String listLimitMessage(int max) {
    return 'You\'ve reached the limit of $max reading lists. Upgrade to Premium to create as many as you want!';
  }

  @override
  String get ok => 'OK';

  @override
  String get goPremium => 'Go Premium';

  @override
  String get editList => 'Edit list';

  @override
  String get newList => 'New list';

  @override
  String get listName => 'List name';

  @override
  String get listNameHint => 'E.g.: Books to read this summer';

  @override
  String get iconLabel => 'Icon';

  @override
  String get colorLabel => 'Color';

  @override
  String get createListBtn => 'Create list';

  @override
  String get defaultListName => 'My list';

  @override
  String get publicList => 'Public list';

  @override
  String get privateList => 'Private list';

  @override
  String get publicListDescription => 'Visible to your friends on your profile';

  @override
  String get privateListDescription => 'Visible only to you';

  @override
  String get addBooksTitle => 'Add books';

  @override
  String get myLibraryTab => 'My library';

  @override
  String get searchTab => 'Search';

  @override
  String get emptyLibrary => 'Empty library';

  @override
  String get useSearchTab => 'Use the Search tab to find and add books.';

  @override
  String get filterLibrary => 'Filter my library...';

  @override
  String get searchTitleAuthor => 'Search a title or author...';

  @override
  String get tryMoreSpecific => 'Try a more specific title';

  @override
  String get searchByTitleAuthor => 'Search a book by title or author';

  @override
  String get noReadingSession => 'No reading session';

  @override
  String get startSessionPrompt => 'Start a session to begin!';

  @override
  String get unknownBook => 'Unknown book';

  @override
  String get inProgressTag => 'In progress';

  @override
  String nPagesRead(int count) {
    return '$count pages';
  }

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get sessionTag => 'SESSION';

  @override
  String get makeVisible => 'Make visible';

  @override
  String get hideSessionBtn => 'Hide session';

  @override
  String get sessionHiddenInfo => 'Session hidden from rankings and feed';

  @override
  String get bookProgression => 'Book progression';

  @override
  String get durationLabel => 'duration';

  @override
  String get pagesReadLabel => 'pages read';

  @override
  String get paceLabel => 'pace';

  @override
  String get sessionProgression => 'Session progression';

  @override
  String plusPages(int count) {
    return '+$count pages';
  }

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get timeline => 'Timeline';

  @override
  String get sessionStart => 'session start';

  @override
  String ofReadingDuration(String duration) {
    return '$duration of reading';
  }

  @override
  String get sessionEnd => 'session end';

  @override
  String get unlockInsights => '✨ Unlock your insights';

  @override
  String get deleteSessionTitle => 'Delete session';

  @override
  String get deleteSessionMessage =>
      'Do you really want to delete this reading session? This action is irreversible.';

  @override
  String get sessionVisible => 'Session visible in rankings';

  @override
  String get errorModifying => 'Error modifying';

  @override
  String get errorDeleting => 'Error deleting';

  @override
  String get loadingError => 'Loading error';

  @override
  String get pagesReadByMonth => 'Pages read by month';

  @override
  String get genreDistribution => 'Genre distribution';

  @override
  String get whenDoYouRead => 'When do you read';

  @override
  String get favoriteSchedules => 'Your favorite reading times of the week';

  @override
  String get yourGoals => 'Your goals';

  @override
  String get noGoalDefined => 'No goal defined';

  @override
  String get defineGoals => 'Define your goals';

  @override
  String get notifications => 'Notifications';

  @override
  String get readingReminders => 'Reading reminders';

  @override
  String get remindersDescription =>
      'Stay motivated with daily reminders to maintain your reading flow.';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get receiveDailyReminders => 'Receive daily reminders';

  @override
  String get reminderDays => 'Reminder days';

  @override
  String get whichDays => 'Which days do you want to be notified?';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get whenReminder => 'When do you want to receive the reminder?';

  @override
  String get aboutNotifications => 'About notifications';

  @override
  String get notificationInfo =>
      'You will receive a notification on selected days to remind you to read and maintain your flow.';

  @override
  String get notificationCenter => 'Notification center';

  @override
  String get notificationCenterDescription =>
      'Manage your notification preferences.';

  @override
  String get friendRequestNotifications => 'Friend requests';

  @override
  String get friendRequestNotificationsDesc =>
      'Get notified of new friend requests';

  @override
  String get emailSection => 'Emails';

  @override
  String get emailSectionDescription =>
      'Choose which notifications you want to receive by email.';

  @override
  String get friendRequestEmail => 'Friend requests by email';

  @override
  String get friendRequestEmailDesc =>
      'Receive an email when someone sends you a friend request';

  @override
  String get pushSection => 'Push notifications';

  @override
  String get pushSectionDescription => 'Notifications on your device.';

  @override
  String get settingsSaved => 'Preferences saved';

  @override
  String get myGoals => 'My goals';

  @override
  String get goalsDescription =>
      'Customize your goals to stay motivated and track your progress.';

  @override
  String get goalsSaved => 'Goals saved!';

  @override
  String get freeGoal => 'Free goal';

  @override
  String get selectedGoals => '💡 Selected goals';

  @override
  String get goalPrefix => 'Goal:';

  @override
  String get saveMyGoals => 'Save my goals';

  @override
  String get goalsModifiable => 'You can change your goals at any time';

  @override
  String get upgradeToLabel => 'Upgrade to';

  @override
  String get lexdayPremium => 'LexDay Premium';

  @override
  String get unlockPotential => 'Unlock the full potential of your reading';

  @override
  String get whatPremiumUnlocks => 'What Premium unlocks';

  @override
  String get seeLess => 'See less';

  @override
  String moreFeatures(int count) {
    return '+$count features';
  }

  @override
  String get choosePlan => 'Choose a plan';

  @override
  String get cannotLoadOffers => 'Cannot load offers';

  @override
  String get startFreeTrial => 'Start free trial';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get freeTrialInfo =>
      '7-day free trial. No immediate payment.\nCancel anytime.';

  @override
  String get monthlyBillingInfo => 'Billed monthly. Cancel anytime.';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get welcomePremium => 'Welcome to LexDay Premium!';

  @override
  String get subscriptionRestored => 'Subscription restored!';

  @override
  String get noSubscriptionFound => 'No subscription found';

  @override
  String get featureHeader => 'FEATURE';

  @override
  String get freeHeader => 'FREE';

  @override
  String get premiumHeader => 'PREMIUM';

  @override
  String get alreadyFree => 'ALREADY INCLUDED FOR FREE';

  @override
  String get annual => 'Annual';

  @override
  String get monthly => 'Monthly';

  @override
  String get yourReadingFlow => 'Your reading flow';

  @override
  String consecutiveDaysActive(int days) {
    return '$days consecutive days, active';
  }

  @override
  String get daysLabel => 'days';

  @override
  String get currentFlow => 'Current flow';

  @override
  String get totalDays => 'total days';

  @override
  String get recordDays => 'record days';

  @override
  String get flowFreeze => 'Flow Freeze';

  @override
  String get autoFreezeActive => 'Auto-freeze active';

  @override
  String get protect => 'Protect';

  @override
  String get unlimited => 'Unlimited';

  @override
  String freezesAvailable(int count) {
    return '$count/2 available';
  }

  @override
  String get exhausted => 'Exhausted';

  @override
  String get premiumAutoFreezes =>
      'Go Premium for unlimited auto-freezes and manual freeze.';

  @override
  String get useFreezeTitle => 'Use freeze?';

  @override
  String get useFreezeMessage =>
      'This will protect your flow for yesterday using a manual freeze.';

  @override
  String get flowHistory => 'Flow history';

  @override
  String get flowHistoryDescription =>
      'Browse your full reading history month by month';

  @override
  String get unlockWithPremium => 'Unlock with Premium';

  @override
  String beatPercentile(int percentile) {
    return 'You beat $percentile% of regular readers.';
  }

  @override
  String get bravoExcl => 'Bravo! ';

  @override
  String get keepReadingTomorrow =>
      'Keep reading tomorrow to maintain your flow!';

  @override
  String get iAcceptThe => 'I accept the ';

  @override
  String get termsOfUseLink => 'Terms of Use';

  @override
  String get ofLexDay => ' of LexDay';

  @override
  String readingNow(String label) {
    return 'Reading · $label';
  }

  @override
  String get amazon => 'Amazon';

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySubtitle => 'your collection';

  @override
  String get filterAll => 'All';

  @override
  String get filterReading => 'Reading';

  @override
  String get filterRead => 'Read';

  @override
  String get filterMyLists => 'My lists';

  @override
  String get seeAll => 'See all';

  @override
  String get currentlyReading => 'Currently reading';

  @override
  String get readBooks => 'Read';

  @override
  String get noCurrentlyReading => 'No books currently reading';

  @override
  String get noReadBooks => 'No books read';

  @override
  String get allReadingBooks => 'Currently reading';

  @override
  String get allFinishedBooks => 'Finished books';

  @override
  String get newSessionSubtitle => 'NEW SESSION';

  @override
  String get startSessionTitle => 'Start';

  @override
  String get whatPageAreYouAt => 'WHAT PAGE ARE YOU AT?';

  @override
  String get scanPageBtn => 'Scan page';

  @override
  String get galleryPageBtn => 'Gallery';

  @override
  String get launchSessionBtn => 'Launch session';

  @override
  String continueFromPage(int page) {
    return 'Continue from page $page';
  }

  @override
  String lastSessionPage(int page) {
    return 'Last session — page $page';
  }

  @override
  String pagesProgress(int current, int total) {
    return '$current / $total pages';
  }

  @override
  String get noPreviousSession => 'First session';

  @override
  String sharedByUser(String name) {
    return 'Shared by $name';
  }

  @override
  String get sessionAnnotations => 'Session annotations';

  @override
  String get annotateButton => 'Annotate';

  @override
  String get comments => 'Comments';

  @override
  String get writeComment => 'Write a comment...';

  @override
  String get commentBeingValidated => 'Comment being validated...';

  @override
  String get commentPending => 'Pending';

  @override
  String get noCommentsYet => 'No comments yet';

  @override
  String get beFirstToComment => 'Be the first to comment!';

  @override
  String get send => 'Send';

  @override
  String get reactionPremiumOnly => 'Reaction reserved for Premium members';

  @override
  String get nearbyBookstores => 'Nearby Bookstores';

  @override
  String get noBookstoresFound => 'No bookstores found nearby';

  @override
  String get openNow => 'Open';

  @override
  String get closed => 'Closed';

  @override
  String get navigate => 'Navigate';

  @override
  String get searchingBookstores => 'Searching for bookstores...';

  @override
  String get offlineBanner => 'Offline — sessions will sync automatically';

  @override
  String get sessionSavedOffline =>
      'Session saved offline. It will sync when you reconnect.';

  @override
  String offlineSyncSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions synced',
      one: '1 session synced',
    );
    return '$_temp0';
  }

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get newNotifications => 'New';

  @override
  String get recentNotifications => 'Recent';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsDesc =>
      'You\'ll be notified of likes, comments and friend requests';

  @override
  String get notifTypeFriends => 'Friends';

  @override
  String get notifTypeLike => 'Like';

  @override
  String get notifTypeComment => 'Comment';

  @override
  String get notifTypeClub => 'Club';

  @override
  String get accept => 'Accept';

  @override
  String get ignore => 'Ignore';

  @override
  String sentYouFriendRequest(String name) {
    return '$name sent you a friend request';
  }

  @override
  String sentGroupJoinRequest(String name, String groupName) {
    return '$name wants to join $groupName';
  }

  @override
  String likedYourReading(String name, String bookTitle) {
    return '$name liked your reading of $bookTitle';
  }

  @override
  String commentedYourReading(String name, String bookTitle) {
    return '$name commented on your reading of $bookTitle';
  }

  @override
  String get prizeSelections => 'LexDay Selections';

  @override
  String get prizeSelectionsSubtitle => 'Official literary prizes';

  @override
  String get officialLexDay => 'Official LexDay';

  @override
  String get bookSummary => 'Book summary';

  @override
  String get noDescriptionAvailable => 'No summary available for this book.';

  @override
  String get buyOnAmazon => 'Buy on Amazon';

  @override
  String get requestToJoin => 'Request to join';

  @override
  String get joinRequestSent => 'Request sent!';

  @override
  String get joinRequestPending => 'Request pending…';

  @override
  String get joinRequestCancelled => 'Request cancelled';

  @override
  String joinRequestAccepted(String name) {
    return '$name has been accepted into the club';
  }

  @override
  String joinRequestRejected(String name) {
    return '$name\'s request rejected';
  }

  @override
  String pendingJoinRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending requests',
      one: '1 pending request',
    );
    return '$_temp0';
  }

  @override
  String get reject => 'Reject';

  @override
  String get readingForLabel => 'I\'M READING FOR';

  @override
  String get readingForJustMe => 'Myself';

  @override
  String get readingForDaughter => 'My daughter';

  @override
  String get readingForSon => 'My son';

  @override
  String get readingForFriend => 'A friend';

  @override
  String get readingForGrandmother => 'My grandmother';

  @override
  String get readingForGrandfather => 'My grandfather';

  @override
  String get readingForPartner => 'My partner';

  @override
  String get readingForFather => 'My father';

  @override
  String get readingForMother => 'My mother';

  @override
  String get readingForOther => 'Other';

  @override
  String readingForDisplay(String person) {
    return 'Read for $person';
  }

  @override
  String get readingForStatsTitle => 'Shared readings';

  @override
  String get readingForStatsSubtitle =>
      'Time spent reading for your loved ones';

  @override
  String readingForNoStats(String person) {
    return 'You don\'\'t have any reading sessions for $person yet';
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
  String get refreshCovers => 'Refresh book covers';

  @override
  String get refreshingCovers => 'Refreshing covers…';

  @override
  String coversRefreshed(int count) {
    return '$count cover(s) updated';
  }

  @override
  String get coversUpToDate => 'All covers are already up to date';

  @override
  String get friendsLabel => 'Friends';
}
