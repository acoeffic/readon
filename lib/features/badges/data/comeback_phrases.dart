import 'dart:math';

/// Phrases de bienvenue retour, 10 par palier de comeback.
/// Sélectionnées aléatoirement lors du débloquage du badge.
const Map<String, List<String>> comebackPhrases = {
  'comeback_3d': [
    'Trois jours sans lire ? On ne t\'en veut pas, les livres t\'attendaient !',
    'Te revoilà ! Tes pages commençaient à s\'ennuyer.',
    'Bon retour ! Trois jours c\'est court, mais tes livres ont compté chaque minute.',
    'La pause est finie, place à la lecture !',
    'Content de te revoir ! Les personnages se demandaient où tu étais.',
    'Trois jours sans toi, c\'était long pour ta bibliothèque.',
    'Et c\'est reparti ! Les mots t\'ont manqué autant que tu leur as manqué.',
    'Bienvenue ! Ta liseuse a rechargé ses batteries, et toi ?',
    'Te revoilà parmi les lecteurs ! On t\'a gardé ta place.',
    'Petite pause terminée, grande lecture en vue !',
  ],
  'comeback_5d': [
    'Cinq jours loin des pages... mais te revoilà, c\'est l\'essentiel !',
    'On commençait à s\'inquiéter ! Bienvenue parmi nous.',
    'Cinq jours sans lire ? Tes livres avaient le cafard.',
    'Le retour du lecteur ! Ta bibliothèque est en fête.',
    'Tu nous as manqué ! Les histoires t\'attendaient avec impatience.',
    'Après cinq jours, rien de tel qu\'une bonne session de lecture.',
    'Re-bienvenue ! Les chapitres non lus te font signe.',
    'Cinq jours c\'est passé, maintenant place aux pages !',
    'Les livres ne t\'oublient jamais, et ils sont ravis de te revoir.',
    'Ton retour est la meilleure nouvelle de la journée !',
  ],
  'comeback_1w': [
    'Une semaine entière sans lire ! Tes livres t\'ont gardé une place au chaud.',
    'Sept jours plus tard, te revoilà ! C\'est un beau jour pour lire.',
    'Une semaine de pause, ça arrive ! L\'important c\'est de revenir.',
    'Bon retour après cette semaine ! Les pages t\'accueillent à bras ouverts.',
    'Tu reviens après une semaine ? Parfait timing, il y a tant à lire !',
    'Les histoires ne vieillissent pas, elles t\'attendaient patiemment.',
    'Après sept jours, ta lampe de lecture est contente de se rallumer.',
    'Semaine chargée ? Pas grave, la lecture est toujours là pour toi.',
    'Un retour en force après une semaine ! On adore ça.',
    'Les personnages de tes livres sont soulagés, tu es de retour !',
  ],
  'comeback_2w': [
    'Deux semaines sans lire... mais quel plaisir de te retrouver !',
    'Quinze jours c\'est long, mais ton retour en vaut la peine !',
    'Te revoilà après deux semaines ! Ta bibliothèque t\'a attendu fidèlement.',
    'Deux semaines de pause, et te voilà de retour plus motivé que jamais !',
    'Les pages se sont accumulées en ton absence. Prêt à rattraper le temps perdu ?',
    'Après deux semaines, rien de tel que de replonger dans un bon livre.',
    'Ton retour après 14 jours ? C\'est comme retrouver un vieil ami.',
    'Les livres ne gardent pas rancune. Ils sont juste heureux que tu sois là.',
    'Deux semaines loin des mots, mais les mots ne t\'ont pas oublié.',
    'Quel bonheur de te revoir ! La lecture t\'ouvre à nouveau ses portes.',
  ],
  'comeback_1m': [
    'Un mois entier ! Ton retour est un véritable événement.',
    'Trente jours sans lire... mais aujourd\'hui marque un nouveau départ !',
    'Un mois plus tard, te revoilà ! Les livres organisent une fête en ton honneur.',
    'Après un mois d\'absence, chaque page lue sera encore plus savoureuse.',
    'Le grand retour ! Un mois c\'est long, mais tu es là et c\'est tout ce qui compte.',
    'Un mois sans lecture ? C\'est du passé. Bienvenue dans le présent !',
    'Tes livres t\'attendaient depuis 30 jours. La patience a payé !',
    'Après un mois, tu reviens avec des yeux neufs. Quelle chance pour tes livres !',
    'Un mois d\'absence, mais zéro jugement. Juste de la joie de te revoir !',
    'Le retour le plus attendu du mois, c\'est le tien !',
  ],
  'comeback_3m': [
    'Trois mois ! Tel un phénix, tu renais de tes cendres littéraires.',
    'Après un trimestre d\'absence, ton retour est légendaire !',
    'Trois mois sans lire... mais te revoilà, et c\'est tout ce qui compte.',
    'Le retour de l\'année ! Trois mois loin des pages, mais jamais oublié.',
    'Comme un livre qu\'on reprend après l\'avoir posé : le plaisir est intact.',
    'Trois mois plus tard, la magie de la lecture t\'accueille à nouveau.',
    'Ton retour après 3 mois prouve une chose : la lecture, c\'est pour la vie.',
    'Les livres sont patients. Après trois mois, ils t\'accueillent sans reproche.',
    'Un trimestre d\'absence ? L\'aventure littéraire ne fait que recommencer !',
    'Trois mois c\'est passé comme un chapitre. Prêt pour la suite ?',
  ],
};

/// Retourne une phrase de bienvenue aléatoire pour le badge comeback donné.
String getRandomComebackPhrase(String badgeId) {
  final phrases = comebackPhrases[badgeId];
  if (phrases == null || phrases.isEmpty) return '';
  return phrases[Random().nextInt(phrases.length)];
}
