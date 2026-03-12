// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navFeed => 'Feed';

  @override
  String get navLibrary => 'Biblio';

  @override
  String get navClub => 'Club';

  @override
  String get navProfile => 'Mi espacio';

  @override
  String get kindleSyncedAutomatically => 'Kindle sincronizado automáticamente';

  @override
  String get enterEmailToReset => 'Introduce tu email para restablecer';

  @override
  String get emailSentCheckInbox =>
      'Email enviado, revisa tu bandeja de entrada.';

  @override
  String get errorSendingEmail => 'Error al enviar el email';

  @override
  String tooManyAttemptsRetryIn(int seconds) {
    return 'Demasiados intentos. Reintenta en ${seconds}s';
  }

  @override
  String get emailAndPasswordRequired => 'Email y contraseña requeridos';

  @override
  String get loginFailed => 'Inicio de sesión fallido';

  @override
  String get unknownError => 'Error desconocido';

  @override
  String get errorSignInApple => 'Error al iniciar sesión con Apple';

  @override
  String get errorSignInGoogle => 'Error al iniciar sesión con Google';

  @override
  String get welcomeBack => 'Bienvenido de nuevo,';

  @override
  String get reader => 'lector.';

  @override
  String get email => 'EMAIL';

  @override
  String get emailLower => 'Email';

  @override
  String get password => 'CONTRASEÑA';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get continueReading => 'Continuar leyendo';

  @override
  String get or => 'o';

  @override
  String get newToLexDay => '¿Nuevo en LexDay? ';

  @override
  String get createAnAccount => 'Crear una cuenta';

  @override
  String get emailAlreadyUsed => 'Email ya en uso';

  @override
  String get emailAlreadyUsedMessage =>
      'Este email ya está asociado a una cuenta existente. ¿Deseas restablecer tu contraseña?';

  @override
  String get back => 'Volver';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetEmailSent =>
      'Email de restablecimiento enviado. Revisa tu bandeja.';

  @override
  String get passwordMin8Chars =>
      'La contraseña debe tener al menos 8 caracteres';

  @override
  String get passwordRequirements =>
      'La contraseña debe contener mayúscula, minúscula y número';

  @override
  String get mustAcceptTerms => 'Debes aceptar las condiciones de uso';

  @override
  String get accountCreatedCheckEmail => 'Cuenta creada, revisa tus emails.';

  @override
  String get createAccountTitle => 'Crear una cuenta';

  @override
  String get joinLexDay => 'Únete a LexDay';

  @override
  String get enterInfoToStart => 'Introduce tus datos para empezar a leer';

  @override
  String get name => 'Nombre';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get yourEmail => 'tu.email@mail.com';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get createAccount => 'Crear una cuenta';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get legalNotices => 'Avisos legales';

  @override
  String get emailSent => 'Email enviado';

  @override
  String get checkYourEmail => 'Revisa tu email';

  @override
  String get confirmEmailSent =>
      'Te hemos enviado un enlace para confirmar tu dirección de email.';

  @override
  String get iConfirmedMyEmail => 'He confirmado mi email';

  @override
  String get suggestionsForYou => 'Sugerencias para ti';

  @override
  String bookAddedToLibrary(String title) {
    return '$title añadido a tu biblioteca';
  }

  @override
  String get errorAddingBook => 'Error al añadir el libro';

  @override
  String get recentSessions => 'Sesiones recientes';

  @override
  String get recentBadges => 'Insignias recientes';

  @override
  String get friendsActivity => 'Actividad de tus amigos';

  @override
  String get refresh => 'Actualizar';

  @override
  String get friendsNotReadToday => 'Tus amigos aún no han leído hoy';

  @override
  String get noActivityYet => 'Sin actividad aún';

  @override
  String get addFriendsToSeeActivity => '¡Añade amigos para ver sus lecturas!';

  @override
  String get shareInviteText =>
      '📖 ¡Únete a mí en LexDay!\n\n¿Qué estás leyendo? 👀\nlexday.app';

  @override
  String errorGeneric(String message) {
    return 'Error: $message';
  }

  @override
  String get myLibrary => 'Mi Biblioteca';

  @override
  String get refreshTooltip => 'Actualizar';

  @override
  String get searchBook => 'Buscar un libro...';

  @override
  String get statusLabel => 'Estado';

  @override
  String get genreLabel => 'Género';

  @override
  String get noBooksInLibrary => 'No hay libros en tu biblioteca';

  @override
  String get scanOrSyncBooks =>
      'Escanea una portada o sincroniza tus libros Kindle';

  @override
  String authorFoundForBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return 'Autor encontrado para $count libro$_temp0';
  }

  @override
  String get noAuthorFound => 'Ningún autor encontrado';

  @override
  String get errorSearchingAuthors => 'Error al buscar autores';

  @override
  String get searchingInProgress => 'Buscando...';

  @override
  String get searchMissingAuthors => 'Buscar autores faltantes';

  @override
  String get settings => 'Ajustes';

  @override
  String get profileSection => 'Perfil';

  @override
  String get editName => '✏️ Editar nombre';

  @override
  String get uploadingPhoto => '📸 Subiendo...';

  @override
  String get changeProfilePicture => '📸 Cambiar foto de perfil';

  @override
  String get subscriptionSection => 'Suscripción';

  @override
  String get upgradeToPremium => 'Pasar a Premium';

  @override
  String get freeTrial => 'Prueba gratuita';

  @override
  String freeTrialUntil(String date) {
    return 'Prueba gratuita (hasta el $date)';
  }

  @override
  String get premiumActive => 'Premium activo';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium activo (hasta el $date)';
  }

  @override
  String get privacySection => 'Privacidad';

  @override
  String get privateProfile => '🔒 Perfil privado';

  @override
  String get statsHidden => 'Tus estadísticas están ocultas';

  @override
  String get statsPublic => 'Tus estadísticas son públicas';

  @override
  String get privateProfileInfoOn =>
      'Los demás usuarios solo verán tu nombre y foto de perfil.';

  @override
  String get privateProfileInfoOff =>
      'Los demás usuarios podrán ver tus insignias, libros, flow y estadísticas.';

  @override
  String get hideReadingHours => '⏱️ Ocultar horas de lectura';

  @override
  String get readingHoursHidden => 'Tus horas de lectura están ocultas';

  @override
  String get readingHoursVisible => 'Tus horas de lectura son visibles';

  @override
  String get readingHoursInfo =>
      'Los demás usuarios no verán tu tiempo total de lectura.';

  @override
  String get profilePrivateEnabled =>
      'Perfil privado activado. Solo tus amigos verán tus estadísticas.';

  @override
  String get profilePublicEnabled =>
      'Perfil público activado. Todos pueden ver tus estadísticas.';

  @override
  String get readingHoursHiddenSnack => 'Horas de lectura ocultas.';

  @override
  String get readingHoursVisibleSnack => 'Horas de lectura visibles.';

  @override
  String get readingSection => 'Lectura';

  @override
  String get editReadingGoal => '🎯 Editar objetivo de lectura';

  @override
  String get flowNotifications => '🔔 Notificaciones de flow';

  @override
  String get kindleSection => 'Kindle';

  @override
  String get resyncKindle => '📚 Resincronizar Kindle';

  @override
  String get connectKindle => '📚 Conectar Kindle';

  @override
  String lastSync(String date) {
    return '✅ Última sync: $date';
  }

  @override
  String get autoSync => 'Sync automática';

  @override
  String get kindleAutoSyncDescription =>
      'Sincroniza tus libros Kindle al abrir la app';

  @override
  String get kindleSyncedSuccess => '¡Kindle sincronizado con éxito!';

  @override
  String get notionSection => 'Notion';

  @override
  String connectedTo(String name) {
    return 'Conectado a $name';
  }

  @override
  String get notionSheetsDescription =>
      'Tus fichas de lectura se pueden enviar a Notion';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get connectNotion => '📝 Conectar Notion';

  @override
  String get notionSyncDescription =>
      'Sincroniza tus fichas de lectura IA con una base de Notion';

  @override
  String get disconnectNotionTitle => '¿Desconectar Notion?';

  @override
  String get disconnectNotionMessage =>
      'Tus fichas ya sincronizadas se mantendrán en Notion.';

  @override
  String get notionDisconnected => 'Notion desconectado';

  @override
  String get appearanceSection => 'Apariencia';

  @override
  String get lightTheme => '🌞 Tema claro';

  @override
  String get lightThemeActive => '🌞 Tema claro (activo)';

  @override
  String get darkTheme => '🌙 Tema oscuro';

  @override
  String get darkThemeActive => '🌙 Tema oscuro (activo)';

  @override
  String get languageSection => 'Idioma';

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
  String get accountSection => 'Cuenta';

  @override
  String get manageConnections => '🖥️ Gestionar conexiones y dispositivos';

  @override
  String get legalSection => 'Legal';

  @override
  String get termsOfService => '📜 Condiciones de uso';

  @override
  String get privacyPolicy => '🔐 Política de privacidad';

  @override
  String get legalNoticesItem => '⚖️ Avisos legales';

  @override
  String get logoutTitle => '¿Cerrar sesión?';

  @override
  String get logoutMessage => 'Se cerrará tu sesión. ¿Continuar?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get logout => '❌ Cerrar sesión';

  @override
  String get dangerZone => 'Zona de peligro';

  @override
  String get deleteAccountWarning =>
      'La eliminación de la cuenta es irreversible.';

  @override
  String get deleteMyAccount => 'Eliminar mi cuenta';

  @override
  String get deleteAccountTitle => '¿Eliminar tu cuenta?';

  @override
  String get deleteAccountMessage =>
      'Esta acción es irreversible. Todos tus datos (libros, sesiones de lectura, insignias, amigos, grupos) serán eliminados permanentemente.';

  @override
  String get continueButton => 'Continuar';

  @override
  String get confirmDeletion => 'Confirmar eliminación';

  @override
  String get typeDeleteToConfirm =>
      'Para confirmar, escribe ELIMINAR a continuación:';

  @override
  String get deleteKeyword => 'ELIMINAR';

  @override
  String get deleteForever => 'Eliminar definitivamente';

  @override
  String errorDeletingAccount(String error) {
    return 'Error al eliminar la cuenta: $error';
  }

  @override
  String get editNameTitle => 'Editar nombre';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get save => 'Guardar';

  @override
  String get nameMinLength => 'El nombre debe tener al menos 2 caracteres';

  @override
  String get nameMaxLength => 'El nombre no debe superar los 50 caracteres';

  @override
  String get nameUpdated => '¡Nombre actualizado!';

  @override
  String get takePhoto => 'Tomar una foto';

  @override
  String get chooseFromGallery => 'Elegir de la galería';

  @override
  String get imageTooLarge => 'Imagen demasiado grande. Tamaño máximo: 5MB';

  @override
  String get unsupportedFormat => 'Formato no soportado. Usa JPG, PNG o WebP';

  @override
  String get notConnected => 'No conectado';

  @override
  String get profilePictureUpdated => '✅ ¡Foto de perfil actualizada!';

  @override
  String timeAgoMinutes(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String timeAgoHours(int hours) {
    return 'hace ${hours}h';
  }

  @override
  String timeAgoDays(int days) {
    return 'hace ${days}d';
  }

  @override
  String get libraryEmpty => 'Tu biblioteca está vacía';

  @override
  String get sessionAbandoned => 'Sesión abandonada';

  @override
  String get muse => '💡 Muse';

  @override
  String get newBook => 'Nuevo libro';

  @override
  String get myLibraryFab => 'Mi biblioteca';

  @override
  String get searchEllipsis => 'Buscar...';

  @override
  String get noBookFound => 'Ningún libro encontrado';

  @override
  String get abandonSessionTitle => 'Abandonar la sesión';

  @override
  String get abandonSessionMessage =>
      '¿Realmente quieres abandonar esta sesión de lectura?';

  @override
  String get no => 'No';

  @override
  String get yes => 'Sí';

  @override
  String get leaveSessionTitle => 'Salir de la sesión';

  @override
  String get leaveSessionMessage =>
      'La sesión sigue activa. Podrás terminarla más tarde.';

  @override
  String get stay => 'Quedarse';

  @override
  String get leave => 'Salir';

  @override
  String get sessionInProgress => 'SESIÓN EN CURSO';

  @override
  String get cancelSessionTitle => 'Cancelar la sesión';

  @override
  String get cancelSessionMessage =>
      '¿Estás seguro de que quieres cancelar esta sesión de lectura?';

  @override
  String errorCapture(String error) {
    return 'Error durante la captura: $error';
  }

  @override
  String get errorGoogleBooks => 'Error en la búsqueda de Google Books';

  @override
  String get termsOfServiceTitle => 'Condiciones de uso';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';

  @override
  String get legalNoticesTitle => 'Avisos legales';

  @override
  String get iAcceptTerms => 'Acepto las condiciones';

  @override
  String get sessionDuration => 'DURACIÓN DE SESIÓN';

  @override
  String get startPage => 'Página de inicio';

  @override
  String get streakLabel => 'Racha';

  @override
  String streakDays(int days) {
    return '$days días';
  }

  @override
  String get endSessionSlide => 'Terminar la sesión';

  @override
  String get abandonButton => 'Abandonar';

  @override
  String get newAnnotation => 'Nueva anotación';

  @override
  String get annotationText => 'Texto';

  @override
  String get annotationPhoto => 'Foto';

  @override
  String get annotationVoice => 'Voz';

  @override
  String get retakePhoto => 'Repetir la foto';

  @override
  String get extractingText => 'Extrayendo texto...';

  @override
  String get micPermissionRequired => 'Permiso de micrófono requerido';

  @override
  String get tapToRecord => 'Toca para grabar';

  @override
  String get recordingInProgress => 'Grabación en curso...';

  @override
  String get retakeRecording => 'Repetir';

  @override
  String get transcriptionInProgress => 'Transcripción en curso...';

  @override
  String get hintExtractedText => 'Texto extraído (editable)...';

  @override
  String get hintTranscription => 'Transcripción (editable)...';

  @override
  String get hintAnnotation => 'Anota tu pensamiento, una cita...';

  @override
  String get voiceAnnotationSaved => '¡Anotación de voz guardada!';

  @override
  String get annotationSaved => '¡Anotación guardada!';

  @override
  String get transcribing => 'Transcribiendo...';

  @override
  String get pageHint => 'Página';

  @override
  String errorSelection(String error) {
    return 'Error durante la selección: $error';
  }

  @override
  String get pageNotDetected =>
      'Número de página no detectado. Introdúcelo manualmente.';

  @override
  String get pageNotDetectedManual =>
      'Número de página no detectado. Puedes introducirlo manualmente a continuación.';

  @override
  String endPageBeforeStartDetailed(int endPage, int startPage) {
    return 'La página final ($endPage) no puede ser anterior a la página de inicio ($startPage).';
  }

  @override
  String ocrError(String error) {
    return 'Error OCR: $error';
  }

  @override
  String get invalidPageNumber =>
      'Por favor, introduce un número de página válido.';

  @override
  String get captureOrEnterPage =>
      'Por favor, toma una foto o introduce un número de página.';

  @override
  String get endPageBeforeStart =>
      'La página final no puede ser anterior a la página de inicio.';

  @override
  String get finishBookTitle => 'Terminar el libro';

  @override
  String get finishBookConfirm => '¡Felicidades! ¿Has terminado este libro?';

  @override
  String get yesFinished => '¡Sí, terminado!';

  @override
  String get endReading => 'Terminar la lectura';

  @override
  String get currentSession => 'Sesión en curso';

  @override
  String startedAtPage(int page) {
    return 'Comenzada en la página $page';
  }

  @override
  String durationValue(String duration) {
    return 'Duración: $duration';
  }

  @override
  String get instructions => 'Instrucciones';

  @override
  String get instructionEndPhoto => '1. Fotografía tu última página leída';

  @override
  String get instructionEndVisible =>
      '2. Asegúrate de que el número sea visible';

  @override
  String get instructionEndValidate => '3. Confirma para guardar tu progreso';

  @override
  String get instructionStartPhoto => '1. Fotografía la página donde empiezas';

  @override
  String get instructionStartVisible =>
      '2. Asegúrate de que el número de página sea visible';

  @override
  String get instructionStartOcr =>
      '3. El OCR detectará automáticamente el número';

  @override
  String get takePhotoBtn => 'Tomar Foto';

  @override
  String get galleryBtn => 'Galería';

  @override
  String get analyzing => 'Analizando...';

  @override
  String get photoCaptured => 'Foto capturada:';

  @override
  String get pageCorrected => 'Página corregida:';

  @override
  String get pageDetected => 'Página detectada:';

  @override
  String pagesReadCount(int count) {
    return 'Páginas leídas: $count';
  }

  @override
  String get correctNumber => 'Corregir el número';

  @override
  String get pageNumberLabel => 'Número de página';

  @override
  String startPagePrefix(int page) {
    return 'Página de inicio: $page';
  }

  @override
  String get validate => 'Validar';

  @override
  String get orEnterManually => 'O introduce el número directamente:';

  @override
  String get startReadingTitle => 'Iniciar una lectura';

  @override
  String get sessionAlreadyActive => 'Ya hay una sesión en curso';

  @override
  String get resumeSession => 'Reanudar la sesión';

  @override
  String get startReadingSession => 'Iniciar la sesión de lectura';

  @override
  String get congratulations => '¡Felicidades!';

  @override
  String get bookFinishedExcl => '¡Libro terminado!';

  @override
  String get continueExcl => '¡Continuar!';

  @override
  String get flowBadgeTitle => '¡Insignia Flow!';

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
    return '¡$days día$_temp0 consecutivo$_temp1!';
  }

  @override
  String museBookFinished(String title) {
    return '¡Bravo por $title! ¿Quieres que Muse te sugiera tu próxima lectura?';
  }

  @override
  String get later => 'Más tarde';

  @override
  String get chatWithMuse => 'Hablar con Muse';

  @override
  String get defaultUser => 'Usuario';

  @override
  String get mySessions => 'Mis Sesiones';

  @override
  String get myStatistics => 'Mis Estadísticas';

  @override
  String get myLists => 'Mis Listas';

  @override
  String get statistics => 'Estadísticas';

  @override
  String get readingStatistics => 'Estadísticas de lectura';

  @override
  String get featureComingSoon => 'Funcionalidad próximamente';

  @override
  String get cannotAddBook => 'No se puede añadir este libro';

  @override
  String get titleAuthorPagesRequired => 'Título, autor y páginas requeridos';

  @override
  String get bookAdded => 'Libro añadido';

  @override
  String get errorAdding => 'Error al añadir';

  @override
  String get addBookTitle => 'Añadir un libro';

  @override
  String get googleBooksSearchTitle => 'Búsqueda en Google Books';

  @override
  String get titleAuthorIsbn => 'Título, autor o ISBN';

  @override
  String get noTitleDefault => 'Sin título';

  @override
  String get addButton => 'Añadir';

  @override
  String get manualAdd => 'Añadir manualmente';

  @override
  String get titleHint => 'Título';

  @override
  String get authorHint => 'Autor';

  @override
  String get totalPages => 'Páginas totales';

  @override
  String get activeSessionDialogTitle => 'Sesión en curso';

  @override
  String get activeSessionDialogMessage =>
      'Ya hay una sesión de lectura en curso para este libro.';

  @override
  String pageAtNumber(int page) {
    return 'Página $page';
  }

  @override
  String get whatDoYouWant => '¿Qué deseas hacer?';

  @override
  String get resume => 'Reanudar';

  @override
  String get sessionCompleted => 'SESIÓN COMPLETADA';

  @override
  String get sessionCompletedTitle => '¡Sesión completada!';

  @override
  String get myReadingDefault => 'Mi lectura';

  @override
  String get durationStatLabel => 'duración';

  @override
  String get pagesReadStatLabel => 'páginas leídas';

  @override
  String get streakStatLabel => 'racha';

  @override
  String streakDaysShort(int days) {
    return '$days d.';
  }

  @override
  String get readingPace => 'Ritmo de lectura';

  @override
  String get avgTimePerPage => 'Tiempo medio por página';

  @override
  String get estimatedBookEnd => 'Fin estimado del libro';

  @override
  String get vsYourAverage => 'vs. tu media';

  @override
  String fasterPercent(int percent) {
    return '+$percent% más rápido';
  }

  @override
  String slowerPercent(int percent) {
    return '$percent% más lento';
  }

  @override
  String get withinAverage => 'Dentro de tu media';

  @override
  String get sessionInsights => 'Insights de la sesión';

  @override
  String get viewFullReport => '✨ Ver informe completo';

  @override
  String get paceAndTrends => 'Ritmo, tendencias, fin estimado y más';

  @override
  String get tryPremium => 'Probar';

  @override
  String get shareSession => 'Compartir la sesión';

  @override
  String get hideSession => 'Ocultar esta sesión';

  @override
  String get sessionHiddenFromRankings => 'Sesión oculta de los rankings';

  @override
  String get errorHidingSession => 'Error al ocultar';

  @override
  String get skip => 'Saltar';

  @override
  String nPages(int count) {
    return '$count páginas';
  }

  @override
  String get bookCompletedHeader => 'LIBRO COMPLETADO';

  @override
  String get bookCompletedTitle => '¡Libro completado!';

  @override
  String get congratsFinished => 'Felicidades, has terminado';

  @override
  String get completed => 'Completado';

  @override
  String get ofReading => 'de lectura';

  @override
  String get sessions => 'sesiones';

  @override
  String readingDaysCount(int count) {
    return '$count días de lectura';
  }

  @override
  String get bookReport => 'Informe del libro';

  @override
  String get avgPace => 'Ritmo medio';

  @override
  String get preferredSlot => 'Horario preferido';

  @override
  String get bestSession => 'Mejor sesión';

  @override
  String get readingRegularity => 'Regularidad de lectura';

  @override
  String get morningSlot => 'Mañana (6h–12h)';

  @override
  String get afternoonSlot => 'Tarde (12h–18h)';

  @override
  String get eveningSlot => 'Noche (18h–22h)';

  @override
  String get nightSlot => 'Noche (22h–6h)';

  @override
  String get unknownSlot => 'Desconocido';

  @override
  String pagesInDuration(int pages, String duration) {
    return '$pages páginas en $duration';
  }

  @override
  String daysPerWeek(String count) {
    return '$count d/sem';
  }

  @override
  String get unlockedBadges => 'Insignias desbloqueadas';

  @override
  String get share => 'Compartir';

  @override
  String get backToHome => 'Volver al inicio';

  @override
  String get paceAndSlots => 'Ritmo, horarios, regularidad y más';

  @override
  String get clubSubtitle => 'comunidad';

  @override
  String get readingClubs => 'Clubs de lectura';

  @override
  String get readingClub => 'Club de lectura';

  @override
  String get myClubs => 'Mis clubs';

  @override
  String get myGroups => 'Mis grupos';

  @override
  String get discover => 'Descubrir';

  @override
  String get createClub => 'Crear un Club';

  @override
  String get noGroups => 'Ningún grupo';

  @override
  String get createOrJoinGroup => 'Crea o únete a un grupo de lectura';

  @override
  String get noPublicGroups => 'Ningún grupo público';

  @override
  String get beFirstToCreate => '¡Sé el primero en crear un grupo público!';

  @override
  String get privateTag => 'Privado';

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
    return '$count miembro$_temp0';
  }

  @override
  String byCreator(String name) {
    return 'por $name';
  }

  @override
  String get limitReached => 'Límite alcanzado';

  @override
  String groupLimitMessage(int max) {
    return 'Has alcanzado el límite de $max clubs de lectura. ¡Pasa a Premium para unirte a los que quieras!';
  }

  @override
  String get becomePremium => 'Ser Premium';

  @override
  String get leaveGroupTitle => '¿Salir del grupo?';

  @override
  String get leaveGroupMessage => '¿Realmente quieres salir de este grupo?';

  @override
  String get leftGroup => 'Has salido del grupo';

  @override
  String get groupNotFound => 'Grupo no encontrado';

  @override
  String get members => 'Miembros';

  @override
  String get activities => 'Actividades';

  @override
  String get activeChallenges => 'Retos activos';

  @override
  String get createChallenge => 'Crear un reto';

  @override
  String get noChallengeActive => 'Ningún reto activo';

  @override
  String get groupActivities => 'Actividades del grupo';

  @override
  String get noActivity => 'Sin actividad';

  @override
  String get activitiesWillAppear =>
      'Las actividades de los miembros aparecerán aquí';

  @override
  String readPagesOf(int pages, String title) {
    return 'ha leído $pages páginas de \"$title\"';
  }

  @override
  String finishedBook(String title) {
    return 'ha terminado \"$title\" 🎉';
  }

  @override
  String get joinedGroup => 'se ha unido al grupo';

  @override
  String recommendsBook(String title) {
    return 'recomienda \"$title\"';
  }

  @override
  String get unknownActivity => 'actividad desconocida';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String get createGroupTitle => 'Crear un grupo';

  @override
  String get addPhoto => 'Añadir una foto';

  @override
  String get groupNameRequired => 'Nombre del grupo *';

  @override
  String get groupNameHint => 'Ej: Club de lectores de ciencia ficción';

  @override
  String get nameRequired => 'El nombre es obligatorio';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get describeGroup => 'Describe tu grupo de lectura...';

  @override
  String get privateGroup => 'Grupo privado';

  @override
  String get inviteOnly => 'Accesible solo por invitación';

  @override
  String get visibleToAll => 'Visible para todos los usuarios';

  @override
  String get creatorAdminInfo =>
      'Como creador, serás automáticamente administrador del grupo y podrás invitar a otros miembros.';

  @override
  String get createGroup => 'Crear el grupo';

  @override
  String get groupCreated => '¡Grupo creado con éxito!';

  @override
  String get allFriendsInGroup => 'Todos tus amigos ya son miembros del grupo';

  @override
  String get inviteFriend => 'Invitar a un amigo';

  @override
  String invitationSent(String name) {
    return '✅ Invitación enviada a $name';
  }

  @override
  String roleUpdated(String name) {
    return 'Rol de $name actualizado';
  }

  @override
  String get removeFromGroupTitle => '¿Eliminar del grupo?';

  @override
  String removeFromGroupMessage(String name) {
    return '¿Quieres eliminar a $name del grupo?';
  }

  @override
  String get removeButton => 'Eliminar';

  @override
  String memberRemoved(String name) {
    return '$name ha sido eliminado del grupo';
  }

  @override
  String get demoteToMember => 'Degradar a miembro';

  @override
  String get promoteAdmin => 'Promover a admin';

  @override
  String get removeFromGroup => 'Eliminar del grupo';

  @override
  String membersCount(int count) {
    return 'Miembros ($count)';
  }

  @override
  String get noMembers => 'Ningún miembro';

  @override
  String get youTag => 'Tú';

  @override
  String get administrator => 'Administrador';

  @override
  String get memberRole => 'Miembro';

  @override
  String get photoUpdated => 'Foto actualizada';

  @override
  String get changesSaved => 'Cambios guardados';

  @override
  String get deleteGroupTitle => '¿Eliminar el grupo?';

  @override
  String get deleteGroupMessage =>
      'Esta acción es irreversible. Todos los miembros serán eliminados y los datos del grupo se perderán.';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get confirmDeleteGroupTitle => 'Confirmar eliminación';

  @override
  String confirmDeleteGroupMessage(String name) {
    return '¿Realmente quieres eliminar \"$name\" definitivamente?';
  }

  @override
  String get groupDeleted => 'Grupo eliminado';

  @override
  String get currentReading => 'Lectura actual';

  @override
  String get noCurrentReading => 'Ningún libro en curso';

  @override
  String get setCurrentReading => 'Definir la lectura del grupo';

  @override
  String get inviteMembers => 'Invitar miembros';

  @override
  String get changeImage => 'Cambiar imagen';

  @override
  String get groupSettings => 'Ajustes del grupo';

  @override
  String get groupPhoto => 'Foto del grupo';

  @override
  String get information => 'Información';

  @override
  String get description => 'Descripción';

  @override
  String get visibility => 'Visibilidad';

  @override
  String get publicGroup => 'Grupo público';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get manageMembers => 'Gestionar miembros';

  @override
  String get manageMembersSubtitle => 'Ver, invitar y gestionar roles';

  @override
  String get deleteChallengeTitle => '¿Eliminar el reto?';

  @override
  String get deleteChallengeMessage => 'Esta acción es irreversible.';

  @override
  String get challengeDeleted => 'Reto eliminado';

  @override
  String get expired => 'Expirado';

  @override
  String daysRemaining(int days) {
    return '${days}d restantes';
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
  String get readABook => 'Leer un libro';

  @override
  String pagesToRead(int count) {
    return '$count páginas por leer';
  }

  @override
  String dailyChallenge(int minutes, int days) {
    return '$minutes min/día durante $days días';
  }

  @override
  String get challengeDetail => 'Detalle del reto';

  @override
  String get leaveChallenge => 'Dejar el reto';

  @override
  String get joinChallenge => 'Unirse al reto';

  @override
  String get leftChallenge => 'Has dejado el reto';

  @override
  String get joinedChallenge => '¡Participas en el reto!';

  @override
  String participantsCount(int count) {
    return 'Participantes ($count)';
  }

  @override
  String get noParticipants => 'Sin participantes';

  @override
  String get challengeCompleted => '¡Completado!';

  @override
  String get challengeInProgress => 'En curso...';

  @override
  String progressPages(int progress, int target) {
    return '$progress / $target páginas';
  }

  @override
  String progressDays(int progress, int target) {
    return '$progress / $target días';
  }

  @override
  String get myProgress => 'Mi progreso';

  @override
  String get completedTag => 'Completado';

  @override
  String get newChallenge => 'Nuevo reto';

  @override
  String get challengeType => 'Tipo de reto';

  @override
  String get challengeTitleRequired => 'Título del reto *';

  @override
  String get challengeTitleHint => 'Ej: Maratón de lectura';

  @override
  String get titleRequired => 'El título es obligatorio';

  @override
  String get deadline => 'Fecha límite';

  @override
  String get createChallengeBtn => 'Crear el reto';

  @override
  String get challengeCreated => '¡Reto creado!';

  @override
  String get pagesType => 'Páginas';

  @override
  String get bookType => 'Libro';

  @override
  String get dailyType => 'Diario';

  @override
  String get bookToRead => 'Libro a leer';

  @override
  String get goalLabel => 'Objetivo';

  @override
  String get pagesCountRequired => 'Número de páginas *';

  @override
  String get pagesCountHint => 'Ej: 200';

  @override
  String get pagesUnit => 'páginas';

  @override
  String get required => 'Obligatorio';

  @override
  String get invalidNumber => 'Número inválido';

  @override
  String get dailyGoal => 'Objetivo diario';

  @override
  String get dailyMinutesRequired => 'Minutos de lectura por día *';

  @override
  String get dailyMinutesHint => 'Ej: 30';

  @override
  String get minPerDay => 'min/día';

  @override
  String get daysCountRequired => 'Número de días *';

  @override
  String get daysCountHint => 'Ej: 7';

  @override
  String get daysUnit => 'días';

  @override
  String get oneWeek => '1 sem.';

  @override
  String get twoWeeks => '2 sem.';

  @override
  String get oneMonth => '1 mes';

  @override
  String get expiresOn => 'Expira el';

  @override
  String get chooseBook => 'Elegir un libro';

  @override
  String get searchBookHint => 'Buscar un libro...';

  @override
  String get noResult => 'Sin resultados';

  @override
  String get selectBookPrompt => 'Por favor, selecciona un libro';

  @override
  String readBookTitle(String title) {
    return 'Leer \"$title\"';
  }

  @override
  String get privateProfileLabel => 'Perfil privado';

  @override
  String privateProfileMessage(String name) {
    return 'Este perfil es privado. Añade a $name como amigo para ver sus estadísticas.';
  }

  @override
  String get books => 'Libros';

  @override
  String get viewFullProfile => 'Ver perfil completo';

  @override
  String get followLabel => 'Seguir';

  @override
  String get pagesLabel => 'Páginas';

  @override
  String get readingLabel => 'Lectura';

  @override
  String get flowLabel => 'Flow';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get noRecentActivity => 'Sin actividad reciente';

  @override
  String get theirBadges => 'Sus insignias';

  @override
  String get removeFriend => 'Eliminar de amigos';

  @override
  String get cancelRequest => 'Cancelar solicitud';

  @override
  String get addFriend => 'Añadir como amigo';

  @override
  String get removeFriendTitle => '¿Eliminar este amigo?';

  @override
  String removeFriendMessage(String name) {
    return '¿Quieres eliminar a $name de tus amigos?';
  }

  @override
  String get requestSent => 'Solicitud enviada';

  @override
  String get requestCancelled => 'Solicitud cancelada';

  @override
  String get friendRemoved => 'Amigo eliminado';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String daysAgo(int days) {
    return 'Hace $days días';
  }

  @override
  String get myFriends => 'Mis amigos';

  @override
  String get findFriends => 'Buscar amigos';

  @override
  String get retry => 'Reintentar';

  @override
  String get noFriendFound => 'Ningún amigo encontrado';

  @override
  String get addFriendsToSeeActivityMessage =>
      '¡Añade amigos para ver su actividad!';

  @override
  String get friendRemovedSnack => 'Amigo eliminado';

  @override
  String cannotRemoveFriend(String error) {
    return 'No se puede eliminar este amigo: $error';
  }

  @override
  String get searchLabel => 'Buscar';

  @override
  String get friends => 'Amigos';

  @override
  String get groups => 'Grupos';

  @override
  String get searchByName => 'Buscar por nombre';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get inviteToRead => 'Invita a tus amigos a leer';

  @override
  String get shareWhatYouRead => 'Comparte lo que estás leyendo ahora';

  @override
  String get typeMin2Chars => 'Escribe al menos 2 caracteres para buscar';

  @override
  String get invitationSentShort => 'Invitación enviada';

  @override
  String get cannotAddFriend => 'No se puede añadir este amigo';

  @override
  String get cannotCancelRequest => 'No se puede cancelar la solicitud';

  @override
  String relationAlreadyExists(String status) {
    return 'Relación ya $status';
  }

  @override
  String get invalidUser => 'Usuario inválido';

  @override
  String get connectToAddFriend => 'Inicia sesión para añadir un amigo';

  @override
  String get errorDuringSearch => 'Error durante la búsqueda';

  @override
  String get firstSessionBravo => '¡Bravo por tu primera\nsesión de lectura!';

  @override
  String get friendsReadToo =>
      'Tus amigos también leen.\n¡Añádelos para ver su actividad!';

  @override
  String get findMyFriends => 'Buscar mis amigos';

  @override
  String get searchingContacts => 'Buscando a tus amigos...';

  @override
  String get noContactOnLexDay => 'Ninguno de tus contactos usa LexDay aún';

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
    return '$count amigo$_temp0 encontrado$_temp1 en LexDay';
  }

  @override
  String get inviteFriendsToJoin => '¡Invita a tus amigos a unirse a LexDay!';

  @override
  String get sent => 'Enviado';

  @override
  String get contactsAccessDenied => 'Acceso a contactos denegado';

  @override
  String get cannotAccessContacts => 'No se puede acceder a los contactos';

  @override
  String get authorizeContactsSettings =>
      'Para encontrar a tus amigos, permite el acceso a contactos en Ajustes.';

  @override
  String get errorOccurredRetryLater =>
      'Ha ocurrido un error. Inténtalo más tarde.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get findContactsFriends => 'Buscar amigos';

  @override
  String get searchingYourContacts => 'Buscando en tus contactos...';

  @override
  String get noContactFound => 'Ningún contacto encontrado';

  @override
  String get contactsNotOnLexDay => 'Tus contactos no parecen usar LexDay aún.';

  @override
  String get alreadyOnLexDay => 'Ya en LexDay';

  @override
  String get inviteToLexDay => 'Invitar a LexDay';

  @override
  String get invited => 'Invitado';

  @override
  String get invite => 'Invitar';

  @override
  String get authorizeContacts =>
      'Para encontrar a tus amigos, permite el acceso a tus contactos.';

  @override
  String get cannotAccessContactsRetry =>
      'No se puede acceder a tus contactos. Inténtalo más tarde.';

  @override
  String get errorOccurred => 'Ha ocurrido un error';

  @override
  String get shareInviteToLexDay =>
      '¡Únete a mí en LexDay para seguir nuestras lecturas juntos! Descarga la app: https://readon.app';

  @override
  String get friendRequests => 'Solicitudes de amistad';

  @override
  String get cannotGetRequests => 'No se pueden obtener las solicitudes';

  @override
  String get friendAdded => 'Amigo añadido';

  @override
  String get requestDeclined => 'Solicitud rechazada';

  @override
  String get actionImpossible => 'Acción imposible';

  @override
  String get noRequest => 'Sin solicitudes';

  @override
  String get museGreeting =>
      'Hola, soy Muse, tu consejera de lectura. ¿Qué te gustaría leer?';

  @override
  String get museRecommendNovel => 'Recomiéndame una novela';

  @override
  String get museSimilarBook => 'Un libro similar al último';

  @override
  String get museClassic => 'Un clásico por descubrir';

  @override
  String freeMessagesUsed(int max) {
    return 'Has usado tus $max mensajes gratuitos este mes';
  }

  @override
  String get subscribeForUnlimited =>
      '¡Suscríbete para chatear con Muse sin límites!';

  @override
  String get discoverSubscription => 'Descubrir la suscripción';

  @override
  String get askRecommendation => 'Pide una recomendación...';

  @override
  String cannotLoadBook(String error) {
    return 'No se puede cargar el libro: $error';
  }

  @override
  String get inBookstore => 'En librería';

  @override
  String get findNearMe => 'Buscar cerca de mí';

  @override
  String get enableLocationSettings => 'Activa la ubicación en Ajustes';

  @override
  String get locationAccessRequired => 'Acceso a la ubicación requerido';

  @override
  String get addToList => 'Añadir a una lista';

  @override
  String get noPersonalList => 'Ninguna lista personal.';

  @override
  String get createNewList => 'Crear una nueva lista';

  @override
  String addedToList(String title) {
    return 'Añadido a \"$title\"';
  }

  @override
  String get deleteConversation => 'Eliminar la conversación';

  @override
  String get deleteConversationConfirm =>
      '¿Estás seguro de que quieres eliminar esta conversación?';

  @override
  String get unlimitedChatbot => 'Uso ilimitado del chatbot, suscríbete';

  @override
  String messagesUsedCount(int used, int max) {
    return '$used/$max mensajes usados este mes';
  }

  @override
  String get noConversation => 'Sin conversaciones';

  @override
  String get startConversationMuse =>
      'Inicia una conversación con Muse para obtener recomendaciones de libros personalizadas.';

  @override
  String get newConversation => 'Nueva conversación';

  @override
  String get readingLists => 'Listas de lectura';

  @override
  String nBooks(int count) {
    return '$count libros';
  }

  @override
  String nReaders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'es',
      one: '',
    );
    return '$count lector$_temp0';
  }

  @override
  String nRead(int read, int total) {
    return '$read/$total leídos';
  }

  @override
  String get deleteListTitle => '¿Eliminar esta lista?';

  @override
  String deleteListMessage(String title) {
    return 'La lista \"$title\" será eliminada permanentemente.';
  }

  @override
  String get editButton => 'Editar';

  @override
  String get addBookToList => 'Añadir un libro';

  @override
  String get noBooksInList => 'No hay libros en esta lista';

  @override
  String get addBooksFromLibrary =>
      'Añade libros desde tu biblioteca o buscando un título.';

  @override
  String get removeBookTitle => '¿Eliminar este libro?';

  @override
  String removeBookMessage(String title) {
    return '¿Eliminar \"$title\" de esta lista?';
  }

  @override
  String get myListsSection => 'Mis listas';

  @override
  String get savedLists => 'Listas guardadas';

  @override
  String get noList => 'Sin listas';

  @override
  String get createListCta =>
      'Crea tu propia lista de lectura o descubre nuestras selecciones.';

  @override
  String get createList => 'Crear una lista';

  @override
  String listLimitMessage(int max) {
    return 'Has alcanzado el límite de $max listas de lectura. ¡Pasa a Premium para crear las que quieras!';
  }

  @override
  String get ok => 'OK';

  @override
  String get goPremium => 'Pasar a Premium';

  @override
  String get editList => 'Editar la lista';

  @override
  String get newList => 'Nueva lista';

  @override
  String get listName => 'Nombre de la lista';

  @override
  String get listNameHint => 'Ej: Libros para leer este verano';

  @override
  String get iconLabel => 'Icono';

  @override
  String get colorLabel => 'Color';

  @override
  String get createListBtn => 'Crear la lista';

  @override
  String get defaultListName => 'Mi lista';

  @override
  String get publicList => 'Lista pública';

  @override
  String get privateList => 'Lista privada';

  @override
  String get publicListDescription => 'Visible para tus amigos en tu perfil';

  @override
  String get privateListDescription => 'Visible solo para ti';

  @override
  String get addBooksTitle => 'Añadir libros';

  @override
  String get myLibraryTab => 'Mi biblioteca';

  @override
  String get searchTab => 'Buscar';

  @override
  String get emptyLibrary => 'Biblioteca vacía';

  @override
  String get useSearchTab =>
      'Usa la pestaña Buscar para encontrar y añadir libros.';

  @override
  String get filterLibrary => 'Filtrar mi biblioteca...';

  @override
  String get searchTitleAuthor => 'Buscar un título o autor...';

  @override
  String get tryMoreSpecific => 'Intenta con un título más específico';

  @override
  String get searchByTitleAuthor => 'Busca un libro por título o autor';

  @override
  String get noReadingSession => 'Sin sesión de lectura';

  @override
  String get startSessionPrompt => '¡Inicia una sesión para empezar!';

  @override
  String get unknownBook => 'Libro desconocido';

  @override
  String get inProgressTag => 'En curso';

  @override
  String nPagesRead(int count) {
    return '$count páginas';
  }

  @override
  String get thisWeek => 'Esta semana';

  @override
  String get thisMonth => 'Este mes';

  @override
  String get sessionTag => 'SESIÓN';

  @override
  String get makeVisible => 'Hacer visible';

  @override
  String get hideSessionBtn => 'Ocultar la sesión';

  @override
  String get sessionHiddenInfo => 'Sesión oculta de los rankings y del feed';

  @override
  String get bookProgression => 'Progreso del libro';

  @override
  String get durationLabel => 'duración';

  @override
  String get pagesReadLabel => 'páginas leídas';

  @override
  String get paceLabel => 'ritmo';

  @override
  String get sessionProgression => 'Progreso de la sesión';

  @override
  String plusPages(int count) {
    return '+$count páginas';
  }

  @override
  String get startLabel => 'Inicio';

  @override
  String get endLabel => 'Fin';

  @override
  String get timeline => 'Cronología';

  @override
  String get sessionStart => 'inicio de sesión';

  @override
  String ofReadingDuration(String duration) {
    return '$duration de lectura';
  }

  @override
  String get sessionEnd => 'fin de sesión';

  @override
  String get unlockInsights => '✨ Desbloquear tus insights';

  @override
  String get deleteSessionTitle => 'Eliminar la sesión';

  @override
  String get deleteSessionMessage =>
      '¿Realmente quieres eliminar esta sesión de lectura? Esta acción es irreversible.';

  @override
  String get sessionVisible => 'Sesión visible en los rankings';

  @override
  String get errorModifying => 'Error al modificar';

  @override
  String get errorDeleting => 'Error al eliminar';

  @override
  String get loadingError => 'Error de carga';

  @override
  String get pagesReadByMonth => 'Páginas leídas por mes';

  @override
  String get genreDistribution => 'Distribución de géneros';

  @override
  String get whenDoYouRead => 'Cuándo lees';

  @override
  String get favoriteSchedules => 'Tus horarios favoritos de la semana';

  @override
  String get yourGoals => 'Tus objetivos';

  @override
  String get noGoalDefined => 'Ningún objetivo definido';

  @override
  String get defineGoals => 'Definir tus objetivos';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get readingReminders => 'Recordatorios de lectura';

  @override
  String get remindersDescription =>
      'Mantente motivado con recordatorios diarios para mantener tu flow de lectura.';

  @override
  String get enableNotifications => 'Activar notificaciones';

  @override
  String get receiveDailyReminders => 'Recibe recordatorios diarios';

  @override
  String get reminderDays => 'Días de recordatorio';

  @override
  String get whichDays => '¿Qué días quieres recibir notificaciones?';

  @override
  String get reminderTime => 'Hora del recordatorio';

  @override
  String get whenReminder => '¿Cuándo quieres recibir el recordatorio?';

  @override
  String get aboutNotifications => 'Sobre las notificaciones';

  @override
  String get notificationInfo =>
      'Recibirás una notificación los días seleccionados para recordarte leer y mantener tu flow.';

  @override
  String get myGoals => 'Mis objetivos';

  @override
  String get goalsDescription =>
      'Personaliza tus objetivos para mantenerte motivado y seguir tu progreso.';

  @override
  String get goalsSaved => '¡Objetivos guardados!';

  @override
  String get freeGoal => 'Objetivo libre';

  @override
  String get selectedGoals => '💡 Objetivos seleccionados';

  @override
  String get goalPrefix => 'Objetivo:';

  @override
  String get saveMyGoals => 'Guardar mis objetivos';

  @override
  String get goalsModifiable =>
      'Podrás modificar tus objetivos en cualquier momento';

  @override
  String get upgradeToLabel => 'Pasa a';

  @override
  String get lexdayPremium => 'LexDay Premium';

  @override
  String get unlockPotential => 'Desbloquea todo el potencial de tu lectura';

  @override
  String get whatPremiumUnlocks => 'Lo que Premium desbloquea';

  @override
  String get seeLess => 'Ver menos';

  @override
  String moreFeatures(int count) {
    return '+$count funcionalidades';
  }

  @override
  String get choosePlan => 'Elegir un plan';

  @override
  String get cannotLoadOffers => 'No se pueden cargar las ofertas';

  @override
  String get startFreeTrial => 'Comenzar prueba gratuita';

  @override
  String get subscribe => 'Suscribirse';

  @override
  String get freeTrialInfo =>
      'Prueba gratuita de 7 días. Sin pago inmediato.\nCancelable en cualquier momento.';

  @override
  String get monthlyBillingInfo =>
      'Facturado mensualmente. Cancelable en cualquier momento.';

  @override
  String get restorePurchases => 'Restaurar mis compras';

  @override
  String get termsOfUse => 'Condiciones de uso';

  @override
  String get welcomePremium => '¡Bienvenido a LexDay Premium!';

  @override
  String get subscriptionRestored => '¡Suscripción restaurada!';

  @override
  String get noSubscriptionFound => 'Ninguna suscripción encontrada';

  @override
  String get featureHeader => 'FUNCIONALIDAD';

  @override
  String get freeHeader => 'GRATIS';

  @override
  String get premiumHeader => 'PREMIUM';

  @override
  String get alreadyFree => 'YA INCLUIDO GRATIS';

  @override
  String get annual => 'Anual';

  @override
  String get monthly => 'Mensual';

  @override
  String get yourReadingFlow => 'Tu flow de lectura';

  @override
  String consecutiveDaysActive(int days) {
    return '$days días consecutivos, activo';
  }

  @override
  String get daysLabel => 'días';

  @override
  String get currentFlow => 'Flow actual';

  @override
  String get totalDays => 'días en total';

  @override
  String get recordDays => 'días récord';

  @override
  String get flowFreeze => 'Flow Freeze';

  @override
  String get autoFreezeActive => 'Auto-freeze activo';

  @override
  String get protect => 'Proteger';

  @override
  String get unlimited => 'Ilimitado';

  @override
  String freezesAvailable(int count) {
    return '$count/2 disponibles';
  }

  @override
  String get exhausted => 'Agotado';

  @override
  String get premiumAutoFreezes =>
      'Pasa a Premium para auto-freezes ilimitados y freeze manual.';

  @override
  String get useFreezeTitle => '¿Usar el freeze?';

  @override
  String get useFreezeMessage =>
      'Esto protegerá tu flow de ayer usando un freeze manual.';

  @override
  String get flowHistory => 'Historial del flow';

  @override
  String get flowHistoryDescription =>
      'Navega por todo tu historial de lectura mes a mes';

  @override
  String get unlockWithPremium => 'Desbloquear con Premium';

  @override
  String beatPercentile(int percentile) {
    return 'Has superado al $percentile% de los lectores regulares.';
  }

  @override
  String get bravoExcl => '¡Bravo! ';

  @override
  String get keepReadingTomorrow =>
      '¡Sigue leyendo mañana para mantener tu flow!';

  @override
  String get iAcceptThe => 'Acepto las ';

  @override
  String get termsOfUseLink => 'Condiciones Generales de Uso';

  @override
  String get ofLexDay => ' de LexDay';

  @override
  String readingNow(String label) {
    return 'Leyendo · $label';
  }

  @override
  String get amazon => 'Amazon';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get librarySubtitle => 'tu colección';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterReading => 'En curso';

  @override
  String get filterRead => 'Leído';

  @override
  String get filterMyLists => 'Mis listas';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get currentlyReading => 'En curso';

  @override
  String get readBooks => 'Leído';

  @override
  String get noCurrentlyReading => 'Ningún libro en curso';

  @override
  String get noReadBooks => 'Ningún libro leído';

  @override
  String get allReadingBooks => 'Libros en curso';

  @override
  String get allFinishedBooks => 'Libros leídos';

  @override
  String get newSessionSubtitle => 'NUEVA SESIÓN';

  @override
  String get startSessionTitle => 'Iniciar';

  @override
  String get whatPageAreYouAt => '¿EN QUÉ PÁGINA ESTÁS?';

  @override
  String get scanPageBtn => 'Escanear página';

  @override
  String get galleryPageBtn => 'Galería';

  @override
  String get launchSessionBtn => 'Iniciar sesión';

  @override
  String continueFromPage(int page) {
    return 'Continuar desde la página $page';
  }

  @override
  String lastSessionPage(int page) {
    return 'Última sesión — página $page';
  }

  @override
  String pagesProgress(int current, int total) {
    return '$current / $total páginas';
  }

  @override
  String get noPreviousSession => 'Primera sesión';

  @override
  String sharedByUser(String name) {
    return 'Compartido por $name';
  }

  @override
  String get sessionAnnotations => 'Anotaciones de la sesión';

  @override
  String get annotateButton => 'Anotar';

  @override
  String get comments => 'Comentarios';

  @override
  String get writeComment => 'Escribe un comentario...';

  @override
  String get commentBeingValidated => 'Comentario en validación...';

  @override
  String get commentPending => 'Pendiente';

  @override
  String get noCommentsYet => 'Aún no hay comentarios';

  @override
  String get beFirstToComment => '¡Sé el primero en comentar!';

  @override
  String get send => 'Enviar';

  @override
  String get reactionPremiumOnly => 'Reacción reservada para miembros Premium';
}
