/// Lien public vers l'app LexDay sur l'App Store.
/// À inclure dans tous les partages sortants.
const String kAppStoreUrl = 'https://apps.apple.com/fr/app/lexday/id6760492023';

/// Facebook App ID utilisé comme `source_application` pour le partage direct
/// vers les Stories Instagram / Facebook.
///
/// ⚠️ REQUIS : Instagram n'ouvre le composer de Story avec l'image préchargée
/// que si `source_application` est un Facebook App ID valide, enregistré sur
/// https://developers.facebook.com (app liée au compte Instagram business).
/// Tant que ce champ vaut le placeholder, le partage Story retombera sur la
/// feuille de partage native (voir StoryShareService).
const String kFacebookAppId = 'REPLACE_WITH_FACEBOOK_APP_ID';
