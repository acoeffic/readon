// lib/models/trophy.dart
// Modèle pour les trophées de session de lecture

enum TrophyType {
  // Contextuels (1-12)
  pageDuJour,
  justeCinqMinutes,
  cafeChapitre,
  lectureDuSoir,
  dernierePageAvantMinuit,
  unePageDePlus,
  rituelDuMatin,
  pauseLecture,
  lectureEclair,
  chapitreVole,
  lectureSansDistraction,
  memeUnParagraphe,
  // Débloquables (13-15)
  lectureImprevue,
  toujoursUnLivre,
  fideliteQuotidienne,
}

extension TrophyTypeData on TrophyType {
  String get id {
    switch (this) {
      case TrophyType.pageDuJour:
        return 'trophy_page_du_jour';
      case TrophyType.justeCinqMinutes:
        return 'trophy_juste_cinq_minutes';
      case TrophyType.cafeChapitre:
        return 'trophy_cafe_chapitre';
      case TrophyType.lectureDuSoir:
        return 'trophy_lecture_du_soir';
      case TrophyType.dernierePageAvantMinuit:
        return 'trophy_derniere_page_avant_minuit';
      case TrophyType.unePageDePlus:
        return 'trophy_une_page_de_plus';
      case TrophyType.rituelDuMatin:
        return 'trophy_rituel_du_matin';
      case TrophyType.pauseLecture:
        return 'trophy_pause_lecture';
      case TrophyType.lectureEclair:
        return 'trophy_lecture_eclair';
      case TrophyType.chapitreVole:
        return 'trophy_chapitre_vole';
      case TrophyType.lectureSansDistraction:
        return 'trophy_lecture_sans_distraction';
      case TrophyType.memeUnParagraphe:
        return 'trophy_meme_un_paragraphe';
      case TrophyType.lectureImprevue:
        return 'trophy_lecture_imprevue';
      case TrophyType.toujoursUnLivre:
        return 'trophy_toujours_un_livre';
      case TrophyType.fideliteQuotidienne:
        return 'trophy_fidelite_quotidienne';
    }
  }

  String get name {
    switch (this) {
      case TrophyType.pageDuJour:
        return 'Page du jour';
      case TrophyType.justeCinqMinutes:
        return 'Juste cinq minutes';
      case TrophyType.cafeChapitre:
        return 'Café & chapitre';
      case TrophyType.lectureDuSoir:
        return 'Lecture du soir';
      case TrophyType.dernierePageAvantMinuit:
        return 'Dernière page avant minuit';
      case TrophyType.unePageDePlus:
        return 'Une page de plus';
      case TrophyType.rituelDuMatin:
        return 'Rituel du matin';
      case TrophyType.pauseLecture:
        return 'Pause lecture';
      case TrophyType.lectureEclair:
        return 'Lecture éclair';
      case TrophyType.chapitreVole:
        return 'Chapitre volé';
      case TrophyType.lectureSansDistraction:
        return 'Lecture sans distraction';
      case TrophyType.memeUnParagraphe:
        return 'Même un paragraphe';
      case TrophyType.lectureImprevue:
        return 'Lecture imprévue';
      case TrophyType.toujoursUnLivre:
        return 'Toujours un livre';
      case TrophyType.fideliteQuotidienne:
        return 'Fidélité quotidienne';
    }
  }

  String get description {
    switch (this) {
      case TrophyType.pageDuJour:
        return 'Vous avez pris un moment pour lire aujourd\'hui.';
      case TrophyType.justeCinqMinutes:
        return 'Même peu de temps compte.';
      case TrophyType.cafeChapitre:
        return 'La journée commence bien.';
      case TrophyType.lectureDuSoir:
        return 'Une page pour terminer la journée.';
      case TrophyType.dernierePageAvantMinuit:
        return 'Vous avez résisté un peu plus longtemps.';
      case TrophyType.unePageDePlus:
        return 'Impossible de s\'arrêter là.';
      case TrophyType.rituelDuMatin:
        return 'Lire avant que le monde ne s\'agite.';
      case TrophyType.pauseLecture:
        return 'Un instant volé au quotidien.';
      case TrophyType.lectureEclair:
        return 'Même brièvement, vous étiez là.';
      case TrophyType.chapitreVole:
        return 'Pris sur le temps, mais pris quand même.';
      case TrophyType.lectureSansDistraction:
        return 'Juste vous et le texte.';
      case TrophyType.memeUnParagraphe:
        return 'C\'était suffisant pour aujourd\'hui.';
      case TrophyType.lectureImprevue:
        return 'Ce n\'était pas prévu, et pourtant.';
      case TrophyType.toujoursUnLivre:
        return 'Il y a toujours quelque chose à lire.';
      case TrophyType.fideliteQuotidienne:
        return 'Vous êtes revenu.';
    }
  }

  String get icon {
    switch (this) {
      case TrophyType.pageDuJour:
        return '✨';
      case TrophyType.justeCinqMinutes:
        return '⏱️';
      case TrophyType.cafeChapitre:
        return '☕';
      case TrophyType.lectureDuSoir:
        return '🌙';
      case TrophyType.dernierePageAvantMinuit:
        return '🕛';
      case TrophyType.unePageDePlus:
        return '📖';
      case TrophyType.rituelDuMatin:
        return '🌅';
      case TrophyType.pauseLecture:
        return '☕';
      case TrophyType.lectureEclair:
        return '⚡';
      case TrophyType.chapitreVole:
        return '🌤️';
      case TrophyType.lectureSansDistraction:
        return '💭';
      case TrophyType.memeUnParagraphe:
        return '📅';
      case TrophyType.lectureImprevue:
        return '🎉';
      case TrophyType.toujoursUnLivre:
        return '📚';
      case TrophyType.fideliteQuotidienne:
        return '💍';
    }
  }

  bool get isUnlockable {
    switch (this) {
      case TrophyType.lectureImprevue:
      case TrophyType.toujoursUnLivre:
      case TrophyType.fideliteQuotidienne:
        return true;
      default:
        return false;
    }
  }
}

class Trophy {
  final TrophyType type;
  final bool isNewlyUnlocked;
  final DateTime? unlockedAt;

  Trophy({
    required this.type,
    this.isNewlyUnlocked = false,
    this.unlockedAt,
  });

  String get id => type.id;
  String get name => type.name;
  String get description => type.description;
  String get icon => type.icon;
  bool get isUnlockable => type.isUnlockable;
}
