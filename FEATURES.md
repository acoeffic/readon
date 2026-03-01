# ReadOn - Fonctionnalités de l'application

ReadOn est une application sociale de lecture qui permet de suivre ses sessions de lecture, maintenir des streaks (flow), collecter des badges, rejoindre des clubs de lecture et interagir avec ses amis lecteurs.

---

## Gratuit vs Premium - Résumé

| Fonctionnalité | Gratuit | Premium |
|----------------|---------|---------|
| Sessions de lecture | Illimitées | Illimitées |
| Bibliothèque de livres | Illimitée | Illimitée |
| Flow (streaks) | Compteur + auto-freeze | + Freeze manuel + historique mois par mois |
| Objectifs de lecture | Tous disponibles | Tous disponibles |
| Badges de base | Tous disponibles | Tous disponibles |
| Badges premium (65+) | Verrouillés | Débloqués (animés, secrets, genres) |
| Listes personnalisées | 5 max | Illimitées |
| Clubs de lecture | 5 max | Illimités |
| Statistiques avancées | Verrouillées | Anneaux d'activité, heatmap, graphiques |
| Réactions avancées | Likes uniquement | Emojis personnalisés |
| Kindle auto-sync | Manuel uniquement | Automatique à chaque ouverture |
| Muse (IA lecture) | 3 messages/mois | Illimité |
| Thèmes personnalisés | Clair/Sombre | Thèmes supplémentaires |
| Monthly & Yearly Wrapped | Disponible | Disponible |
| Feed social | Complet | Complet |
| Amis & notifications | Complet | Complet |
| Widget iOS | Disponible | Disponible |

---

## 1. Authentification & Onboarding

### Authentification
- Inscription par email/mot de passe via Supabase
- Confirmation d'email obligatoire
- Réinitialisation de mot de passe
- Persistance de session automatique

### Onboarding (8 étapes)
1. Écran de bienvenue
2. Sélection des habitudes de lecture (Kindle, papier, ou mixte)
3. Connexion Kindle (pour les utilisateurs Kindle)
4. Synchronisation de la progression Kindle
5. Confirmation de synchronisation
6. Ajout manuel de livres (pour les lecteurs papier)
7. Première session de lecture
8. Suggestions de lecteurs à suivre

---

## 2. Sessions de lecture

### Démarrer une session
- Bouton d'action flottant (FAB) accessible depuis toute l'application
- Capture du numéro de page actuel (OCR automatique ou saisie manuelle)
- Détection OCR via Google ML Kit (formats supportés : numéro seul, "Page XXX", "p. XXX", "| XXX |", "- XXX -")

### Session active
- Chronomètre en temps réel (HH:MM:SS)
- Possibilité de mettre en pause, annuler ou terminer la session

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
- Filtrage par genre
- Recherche par titre et auteur
- Fiche détaillée par livre (couverture, métadonnées, progression, sessions)
- Masquer des livres (non visibles par les autres utilisateurs)
- Suppression par balayage
- Dates de début et de fin de lecture

---

## 4. Intégration Kindle

- Connexion via WebView OAuth Amazon
- Import automatique de la bibliothèque Kindle
- Synchronisation des données : titres, auteurs, couvertures, progression (%), dernière date de lecture
- Passage automatique au statut "Terminé" quand un livre atteint 100%
- Re-synchronisation manuelle possible

### Kindle Auto-Sync (Premium)
- Synchronisation automatique de la bibliothèque Kindle au lancement de l'application
- Intervalle de 24 heures entre chaque synchronisation automatique
- Activable/désactivable dans les préférences utilisateur (activé par défaut)
- Conditions intelligentes : ne se déclenche pas si Kindle jamais connecté, si désactivé, ou si dernière sync récente (<24h)

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
- **Livre terminé** : cartes de célébration pour les livres finis
- **Progrès de lecture** : mises à jour de progression
- **Jalons de flow** : milestones de streaks atteints
- **Suggestions personnalisées** : basées sur les lectures des amis et l'historique
- **Livres tendance** : les plus lus de la semaine (cache 15 min)
- **Sessions communautaires** : sessions récentes des profils publics
- **Badges communautaires** : derniers badges débloqués par la communauté
- **Listes curées** : collections de lecture éditoriales
- **Lecteurs actifs** : aperçu des lecteurs actifs
- **Bannière "Inviter des amis"** : incitation à inviter ses contacts
- **CTA "Trouver des amis"** : incitation à ajouter des contacts

---

## 6. Flow (Streaks de lecture)

### Suivi du flow
- Compteur de jours consécutifs de lecture
- Record personnel (plus long flow)
- Percentile du flow par rapport à la communauté
- Date de dernière lecture

### Streak Freeze
- **Auto-freeze** (tous les utilisateurs) : protection automatique gérée par le système
- **Freeze manuel** (Premium) : protéger manuellement 1 journée passée par mois

### Historique du flow (Premium)
- Navigation mois par mois dans le calendrier de lecture
- Visualisation des jours lus, des jours manqués et des jours gelés

---

## 7. Objectifs de lecture

3 catégories d'objectifs configurables :

### Quantité
- Nombre de livres par an (6, 12, 24, 52 ou personnalisé)

### Régularité
- Jours de lecture par semaine
- Objectif de streak (jours consécutifs)
- Minutes de lecture par jour

### Qualité / Intention
- Livres non-fiction lus
- Livres fiction lus
- Terminer les livres commencés (% complétion)
- Diversité de genres

Chaque objectif affiche une barre de progression et peut être modifié à tout moment.

---

## 8. Badges & Trophées

### Badges (succès permanents)

#### Badges gratuits
- **Livres lus** : paliers de livres terminés (ex : 10, 25, 50 livres)
- **Temps de lecture** : paliers de temps cumulé
- **Streak** : paliers de jours consécutifs (ex : 7, 30, 100 jours)
- **Ancienneté** : badges de fidélité sur la plateforme (1 an, 2 ans, 3 ans)

#### Badges premium (65+)
- **Badges de genre** : SF, biographie, histoire, horreur, romance, développement personnel, etc.
- **Badges sociaux** : fondateur de club, leader de club (10+ membres)
- **Badges secrets** : conditions de déblocage cachées
- **Badges animés** : effets visuels spéciaux

#### Badges d'anniversaire
| Badge | Année | Statut |
|-------|-------|--------|
| Première Bougie | 1 an | Gratuit |
| Lecteur Fidèle | 2 ans | Gratuit |
| Sage des Pages | 3 ans | Gratuit |
| Étoile Littéraire | 4 ans | Premium |
| Légende Vivante | 5 ans | Premium |

**Fonctionnement :**
- Détection automatique au lancement et à la reprise de l'application
- Fenêtre de grâce de 7 jours après la date d'anniversaire
- Animation de déblocage en 5 phases (teaser, burst, révélation, statistiques, partage)
- Génération d'une carte partageable avec le badge et les stats de l'année
- Affichage unique (ne se réaffiche pas après fermeture)

### Affichage des badges
- 3 badges les plus récents affichés sur le profil
- Grille complète sur la page "Tous les badges" avec filtrage par catégorie
- Barres de progression pour les badges verrouillés
- Animation confetti au déblocage
- Popup de notification lors du déblocage

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

Trophées débloquables (long terme) :
- Lecture imprévue
- Toujours un livre
- Fidélité quotidienne

---

## 9. Muse - Conseillère lecture IA (Premium)

### Fonctionnalités
- Chat conversationnel multi-tour avec une IA spécialisée en lecture
- Recommandations de livres personnalisées
- Détection automatique des livres mentionnés dans la conversation
- Ajout direct des livres recommandés dans la bibliothèque ou les listes

### Limites
- **Gratuit** : 3 messages par mois
- **Premium** : illimité

### Conversations
- Sauvegarde des fils de conversation
- Reprise de conversations précédentes
- Historique des conversations passées

---

## 10. Listes de lecture

### Listes personnalisées
- Création de listes de lecture personnalisées
- Ajout/suppression de livres dans les listes
- Renommage et suppression de listes
- **Gratuit** : 5 listes max
- **Premium** : illimité

### Listes curées (éditoriales)
- Collections de lecture recommandées par l'équipe
- Page de catalogue avec compteurs de lecteurs
- Ajout de livres en un clic dans la bibliothèque
- Possibilité de sauvegarder des listes curées en favoris

---

## 11. Amis & Social

### Gestion des amis
- Recherche d'utilisateurs par nom/email
- Envoi/acceptation/refus de demandes d'amitié
- Liste d'amis avec statut
- Suppression d'amis

### Suggestions de contacts
- Import des contacts du téléphone (avec permission)
- Matching par hash SHA-256 des emails/numéros (respect de la vie privée)
- Suggestions d'amis basées sur les contacts
- Suggestions de lecteurs depuis l'onboarding

### Profil ami
- Consultation du profil des amis
- Livres en cours, badges, statistiques
- Respect des paramètres de confidentialité

---

## 12. Interactions sociales

### Likes
- Liker les activités de lecture des amis
- Compteur de likes par activité

### Réactions avancées (Premium)
4 types de réactions :
- Feu
- Livre
- Applaudissement
- Coeur

### Commentaires
- Commenter les activités de lecture
- Limite de 500 caractères
- Suppression de ses propres commentaires

### Notifications
- Types : likes, commentaires, demandes d'amitié, badges débloqués, jalons de flow
- Marquer comme lu (individuellement ou tout d'un coup)
- Compteur de notifications non lues
- Paramètres de notification configurables
- Rappels mensuels de notification

---

## 13. Clubs de lecture

### Création et gestion
- Groupes publics ou privés
- Rôles : administrateur / membre
- Invitation de membres
- Paramètres du groupe (admin)
- **Gratuit** : 5 clubs max
- **Premium** : illimité

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
- Chat entre membres
- Voir ce que les membres lisent

---

## 14. Statistiques

### Statistiques de base (Gratuit)
- Total de livres lus
- Temps de lecture total
- Streak actuel
- Genre favori

### Statistiques avancées (Premium)
- Anneaux d'activité (style Apple Watch)
- Pages par mois (graphique de tendance)
- Distribution des genres (graphique)
- Heatmap de lecture (vue calendrier)
- Records personnels (plus longue session, plus de pages en un jour, etc.)
- Aperçu des badges
- Répartition mensuelle détaillée

---

## 15. Suggestions de livres

Moteur de recommandation hybride :
- **Populaires chez les amis** : livres les plus lus par les amis (max 3)
- **Même auteur** : recommandations basées sur les livres terminés (max 2)
- **Google Books API** : suggestions basées sur les centres d'intérêt
- Déduplication automatique (exclut les livres déjà en bibliothèque)
- Ajout direct en bibliothèque depuis la suggestion
- Carrousel de suggestions dans le feed

---

## 16. Monthly Wrapped

Résumé mensuel de lecture, inspiré de Spotify Wrapped, avec musique de fond et slides animés.

### 5 slides
1. **Titre** : nom du mois avec dégradé thématique et emoji
2. **Statistiques** : temps de lecture total, sessions, livres terminés/en cours, plus longue session, meilleur jour de la semaine
3. **Calendrier** : heatmap visuel de l'activité de lecture quotidienne du mois
4. **Livre phare** : couverture, titre, auteur et temps passé sur le livre le plus lu
5. **Partage** : comparaison avec le mois précédent, badges gagnés, résumé partageable

### Caractéristiques
- **Thème par mois** : chaque mois a des couleurs de dégradé, une couleur d'accent et un emoji uniques
- **Musique de fond** : mélodie ambiante en boucle avec fondu d'entrée/sortie
- **Toggle mute** : possibilité de couper le son
- **Navigation** : points de navigation, gestes de swipe
- **Comparaison** : évolution par rapport au mois précédent (pourcentage)

---

## 17. Yearly Wrapped

Résumé annuel de lecture complet avec 10 slides cinématiques, inspiré de Spotify Wrapped.

### 10 slides
1. **Ouverture** : accueil avec année et nom d'utilisateur
2. **Temps** : temps de lecture total, sessions, durée moyenne par session
3. **Livres** : livres terminés avec graphique de répartition mensuelle
4. **Genres** : top 5 des genres avec pourcentages et barres visuelles
5. **Habitudes** : profil de lecteur (Oiseau de Nuit / Lève-Tôt / etc.), heure de pointe, jours actifs, meilleur streak
6. **Top Livres** : top 5 des livres les plus lus avec couvertures
7. **Jalons** : réalisations clés (plus longue session, meilleur streak, mois le plus productif, badges gagnés)
8. **Social** : classement en percentile parmi tous les utilisateurs
9. **Évolution** : comparaison année par année avec les stats de l'année précédente
10. **Conclusion** : remerciement avec option de partage

### Caractéristiques
- **Musique ambiante** : sélection aléatoire parmi 3 pistes ambiantes depuis Supabase Storage
- **Thème doré** : fond sombre élégant avec accents dorés et texte crème
- **Animations** : animations fade-up, décorateurs ligne dorée, graphiques barres mensuels
- **Profilage lecteur** : classification en Oiseau de Nuit, Lève-Tôt, Lecteur de Midi ou d'Après-midi
- **Comparaison sociale** : classement en percentile par rapport à tous les utilisateurs
- **Génération de cartes partageables**

---

## 18. Partage de badges

- Génération de cartes visuelles pour chaque badge débloqué
- Partage sur les réseaux sociaux
- Edge function Supabase pour la génération côté serveur
- Stockage des cartes dans Supabase Storage

---

## 19. Widget iOS (Home Screen)

- Affichage du livre en cours de lecture (titre et auteur)
- Temps de lecture du jour (en minutes)
- Streak actuel (icône flamme)
- Barre de progression du livre
- Mise à jour horaire
- Thème vert/crème cohérent avec l'application

---

## 20. Profil & Paramètres

### Profil utilisateur
- Nom d'affichage, avatar (upload photo depuis caméra/galerie)
- Message "Lecteur motivé depuis..." basé sur l'ancienneté du compte
- Galerie de badges (3 plus récents + page complète)

### 3 onglets du profil
1. **Sessions** : historique de toutes les sessions de lecture avec pagination
2. **Stats** : statistiques de base (gratuit) et avancées (premium)
3. **Listes** : listes personnalisées et listes curées sauvegardées

### Paramètres
- **Photo de profil** : upload/modification de l'avatar
- **Thème** : clair / sombre / système (+ thèmes personnalisés en premium)
- **Langue** : français / anglais
- **Confidentialité** :
  - Profil privé (seuls les amis voient l'activité)
  - Masquer les heures de lecture
- **Kindle** : connexion, dernière sync, re-sync manuelle, auto-sync (premium)
- **Notifications** : paramètres mensuels, rappels d'objectifs
- **Objectifs de lecture** : configuration/modification des cibles
- **Suppression de compte** : avec suppression en cascade de toutes les données

---

## 21. Abonnement Premium

### Intégration RevenueCat
- Gestion des abonnements via RevenueCat
- Packages mensuel et annuel
- Période d'essai (trial)
- Restauration des achats
- Gestion des problèmes de facturation

### États d'abonnement
- `free` : pas d'abonnement actif
- `trial` : période d'essai en cours
- `premium` : abonnement payé actif
- `expired` : abonnement expiré
- `billing_issue` : problème de moyen de paiement

### Page d'upgrade
- Présentation de toutes les fonctionnalités premium
- Toggle annuel/mensuel
- Affichage des prix
- Bouton d'achat
- Option de restauration des achats

---

## 22. Navigation

4 onglets principaux + FAB central :

| Onglet | Contenu |
|--------|---------|
| Feed | Activités sociales et tendances |
| Biblio | Bibliothèque de livres |
| Club | Groupes et challenges |
| Mon espace | Profil et paramètres |

Bouton flottant central (FAB) pour démarrer une session de lecture depuis n'importe quel écran.

---

## 23. Stack technique

| Composant | Technologie |
|-----------|------------|
| Framework | Flutter |
| Backend | Supabase (auth, DB, RLS, Storage, Edge Functions) |
| State management | Provider |
| Abonnement | RevenueCat |
| OCR | Google ML Kit |
| Recherche de livres | Google Books API |
| Contacts | flutter_contacts |
| Auth Kindle | WebView OAuth |
| Audio | audioplayers (musique Wrapped) |
| Hashing | SHA-256 (pgcrypto + dart crypto) |
| Polices | Poppins, Inter |
| Widget iOS | WidgetKit (SwiftUI) |
| Langue | Français (interface), Anglais (code) |
