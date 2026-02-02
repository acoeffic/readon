# ReadOn - Fonctionnalités de l'application

ReadOn est une application sociale de lecture qui permet de suivre ses sessions de lecture, maintenir des streaks, rejoindre des groupes de lecture et interagir avec ses amis lecteurs.

---

## 1. Authentification & Onboarding

### Authentification
- Inscription par email/mot de passe via Supabase
- Confirmation d'email obligatoire
- Persistance de session automatique

### Onboarding (8 étapes)
1. Écran de bienvenue
2. Sélection des habitudes de lecture (Kindle, papier, ou mixte)
3. Connexion Kindle (pour les utilisateurs Kindle)
4. Synchronisation de la progression Kindle
5. Confirmation de synchronisation
6. Ajout manuel de livres (pour les lecteurs papier)
7. Première session de lecture
8. Finalisation du profil

---

## 2. Sessions de lecture

### Démarrer une session
- Bouton d'action flottant (FAB) accessible depuis toute l'application
- Capture du numéro de page actuel (OCR automatique ou saisie manuelle)
- Détection OCR via Google ML Kit (formats supportés : numéro seul, "Page XXX", "p. XXX", "| XXX |", "- XXX -")

### Session active
- Chronomètre en temps réel (HH:MM:SS)
- Possibilité d'annuler ou terminer la session

### Fin de session
- Capture du numéro de page final
- Calcul automatique : pages lues, durée, vitesse de lecture
- Attribution de trophées contextuels

### Résumé de session
- Statistiques détaillées (pages, durée, temps par page)
- Trophée obtenu avec message de célébration

---

## 3. Bibliothèque de livres

### Ajout de livres
- **Recherche Google Books** : recherche par titre, auteur ou ISBN
- **Scan de couverture** : détection ISBN via OCR depuis une photo
- **Import Kindle** : synchronisation automatique de la bibliothèque Kindle
- **Saisie manuelle** : ajout libre

### Gestion de la bibliothèque
- 3 catégories : En cours / À lire / Terminés
- Fiche détaillée par livre (couverture, métadonnées, progression, sessions)
- Masquer des livres (non visibles par les autres utilisateurs)
- Suppression par balayage

---

## 4. Intégration Kindle

- Connexion via WebView OAuth Amazon
- Import automatique de la bibliothèque Kindle
- Synchronisation des données : titres, auteurs, couvertures, progression (%), dernière date de lecture
- Passage automatique au statut "Terminé" quand un livre atteint 100%
- Re-synchronisation manuelle possible

---

## 5. Feed social (3 niveaux)

Le feed s'adapte au nombre d'amis de l'utilisateur :

| Amis | Contenu du feed |
|------|----------------|
| 0 | Tendances communautaires, sessions récentes, suggestions |
| 1-2 | Mix : activités des amis + contenu communautaire |
| 3+ | Activités des amis uniquement + suggestions personnalisées |

### Composants du feed
- **Carte "Continuer la lecture"** : accès rapide au livre en cours
- **Streak actuel** : affichage du streak avec état du freeze
- **Activités des amis** : livre lu, durée, pages, couverture
- **Suggestions personnalisées** : basées sur les lectures des amis et l'historique
- **Livres tendance** : les plus lus de la semaine (cache 15 min)
- **Sessions communautaires** : sessions récentes des profils publics
- **CTA "Trouver des amis"** : incitation à ajouter des contacts

---

## 6. Streaks de lecture

### Suivi des streaks
- Compteur de jours consécutifs de lecture
- Record personnel (plus long streak)
- Calendrier visuel des jours de lecture

### Streak Freeze
- Protection d'une journée manquée pour maintenir le streak
- Freeze automatique pour les utilisateurs Premium
- Historique des jours protégés
- Gestion depuis la page détail du streak

---

## 7. Objectifs de lecture

3 catégories d'objectifs configurables :

### Quantité
- Nombre de livres par an

### Régularité
- Jours de lecture par semaine
- Objectif de streak
- Minutes de lecture par jour

### Qualité
- Livres non-fiction lus
- Livres fiction lus
- Terminer les livres commencés
- Diversité de genres

Chaque objectif affiche une barre de progression et peut être modifié à tout moment.

---

## 8. Badges & Trophées

### Badges (succès permanents)
- **Catégorie Quantité** : paliers de livres lus (ex : 10, 25, 50 livres)
- **Catégorie Régularité** : paliers de streak (ex : 7, 30, 100 jours)
- **Catégorie Qualité** : diversité de genres, habitudes de lecture
- Progression visible vers les badges non débloqués
- Notification popup lors du déblocage

### Trophées (récompenses de session)
Attribués après chaque session selon le contexte :

| Trophée | Condition |
|---------|-----------|
| Même Un Paragraphe | Session très courte |
| Lecture Éclair | ~5 minutes |
| Juste Cinq Minutes | Session de 5 min |
| Lecture Sans Distraction | 30+ minutes |
| Une Page De Plus | 45+ minutes |
| Dernière Page Avant Minuit | Lecture tardive |
| Rituel Du Matin | Lecture matinale |
| Café & Chapitre | Pause café |
| Pause Lecture | Pause déjeuner |
| Chapitre Volé | Lecture volée dans la journée |
| Lecture Du Soir | Session en soirée |
| Page Du Jour | Beaucoup de pages lues |

---

## 9. Amis & social

### Gestion des amis
- Recherche d'utilisateurs par nom/email
- Envoi/acceptation/refus de demandes d'amitié
- Liste d'amis avec statut
- Suppression d'amis

### Suggestions de contacts
- Import des contacts du téléphone (avec permission)
- Matching par hash SHA-256 des emails/numéros (respect de la vie privée)
- Suggestions d'amis basées sur les contacts

### Profil ami
- Consultation du profil des amis
- Livres en cours, badges, statistiques

---

## 10. Groupes de lecture

### Création et gestion
- Groupes publics ou privés
- Rôles : administrateur / membre
- Invitation de membres
- Paramètres du groupe (admin)
- Ajout/suppression de membres

### Challenges de groupe
- Création de défis avec :
  - Type : pages, livres ou temps
  - Objectif cible
  - Livre cible (optionnel)
  - Date limite
- Suivi de la progression des participants
- Classement (leaderboard)
- Challenges mensuels/hebdomadaires

### Activité du groupe
- Feed d'activités spécifique au groupe
- Voir ce que les membres lisent

---

## 11. Interactions sociales

### Likes
- Liker les activités de lecture des amis
- Compteur de likes par activité

### Réactions avancées (Premium)
4 types de réactions :
- 🔥 Feu
- 📘 Livre
- 👏 Applaudissement
- ❤️ Coeur

### Commentaires
- Commenter les activités de lecture
- Limite de 500 caractères
- Suppression de ses propres commentaires

### Notifications
- Types : likes, commentaires, demandes d'amitié
- Marquer comme lu (individuellement ou tout d'un coup)
- Compteur de notifications non lues
- Paramètres de notification configurables

---

## 12. Suggestions de livres

Moteur de recommandation hybride :
- **Populaires chez les amis** : livres les plus lus par les amis (max 3)
- **Même auteur** : recommandations basées sur les livres terminés (max 2)
- **Google Books API** : suggestions basées sur les centres d'intérêt
- Déduplication automatique (exclut les livres déjà en bibliothèque)
- Ajout direct en bibliothèque depuis la suggestion

---

## 13. Premium

### Fonctionnalités Premium
- Réactions avancées (🔥 📘 👏 ❤️)
- Streak auto-freeze
- Vérification du statut avec cache (TTL 5 min)
- Suivi de la date d'expiration

---

## 14. Profil & paramètres

### Profil utilisateur
- Nom d'affichage, avatar (upload photo)
- Objectif principal affiché
- Galerie de badges
- Statistiques de lecture

### Paramètres
- **Visibilité du profil** : public / privé
- **Thème** : clair / sombre
- **Notifications** : personnalisation par type et fréquence
- **Suppression de compte** : avec suppression en cascade de toutes les données

### Conditions d'utilisation
- Page dédiée aux CGU
- Acceptation obligatoire à l'inscription

---

## 15. Navigation

5 onglets principaux :

| Onglet | Contenu |
|--------|---------|
| Feed | Activités sociales et tendances |
| Sessions | Historique des sessions de lecture |
| Bibliothèque | Collection de livres |
| Club | Groupes et challenges |
| Profil | Profil et paramètres |

Bouton flottant global pour démarrer une session de lecture depuis n'importe quel écran.

---

## 16. Stack technique

| Composant | Technologie |
|-----------|------------|
| Framework | Flutter 3.9.2+ |
| Backend | Supabase (auth, DB, RLS) |
| State management | Provider 6.1.1 |
| OCR | Google ML Kit |
| Recherche de livres | Google Books API |
| Contacts | flutter_contacts |
| Authentification Kindle | WebView OAuth |
| Hashing | SHA-256 (pgcrypto + dart crypto) |
| Polices | Poppins, Inter |
| Langue | Français (interface), Anglais (code) |
