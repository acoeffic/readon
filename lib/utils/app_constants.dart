/// Lien public vers l'app LexDay sur l'App Store.
/// À inclure dans tous les partages sortants.
const String kAppStoreUrl = 'https://apps.apple.com/fr/app/lexday/id6760492023';

/// Lien public vers l'app LexDay sur le Play Store.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.acoeffic.lexday';

/// Page de renvoi neutre du site : détecte la plateforme et oriente vers le
/// bon store (ou ouvre l'app si elle est installée).
///
/// ⚠️ Ne plus mettre `kAppStoreUrl` en dur dans un texte de partage : un
/// destinataire Android recevait un lien App Store, donc rien. Passer par
/// `ReferralService.shareUrl`, qui renvoie le lien de parrainage personnel
/// (attribué) et retombe sur cette page à défaut.
const String kShareLandingUrl = 'https://www.lexday.fr/redirect.html?to=feed';

/// Facebook App ID utilisé comme `source_application` pour le partage direct
/// vers les Stories Instagram / Facebook.
///
/// ⚠️ REQUIS : Instagram n'ouvre le composer de Story avec l'image préchargée
/// que si `source_application` est un Facebook App ID valide, enregistré sur
/// https://developers.facebook.com (app liée au compte Instagram business).
/// Tant que ce champ vaut le placeholder, le partage Story retombera sur la
/// feuille de partage native (voir StoryShareService).
const String kFacebookAppId = 'REPLACE_WITH_FACEBOOK_APP_ID';
