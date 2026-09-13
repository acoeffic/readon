# CPP « Club de lecture » — page produit personnalisée App Store

> Objectif : convertir les recherches « club de lecture » / « défi lecture » (Apple Ads), qui tapent sur l'annonce (TTR 3,56 %) mais ne téléchargent jamais (0/16) parce que la fiche actuelle montre un tracker solo. La CPP leur montre le LexDay social.
>
> Règle d'or : **ne montrer que ce qui existe** (feed, amis, commentaires, listes). Pas de « clubs » fictifs ni de groupes constitués — sinon on paie l'install et on déplace la déception dans l'app.

## 1. Texte promotionnel (≤ 170 caractères)

> Votre cercle de lecture dans la poche : suivez vos amis, commentez leurs lectures et avancez ensemble, un livre à la fois.

(121 caractères. Variante plus courte si besoin : « Suivez vos amis lecteurs, commentez leurs lectures, avancez ensemble. »)

## 2. Screenshots (1284×2778, template « sauge premium » existant)

Les annonces de recherche n'affichent que les **3 premiers** en portrait — l'ordre est décisif. Mêmes gabarits que `appstore_screenshots/` (fond sauge dégradé + vagues, titre Libre Baskerville avec mot-clé italique #466B62 souligné doré, sous-titre Inter, cadre iPhone).

| # | Écran à capturer | Titre (italique = mot souligné) | Sous-titre |
|---|---|---|---|
| 1 | Feed d'activité (fil des lectures des amis) | Lisez *ensemble* | Le fil de lecture de vos amis, en temps réel |
| 2 | Commentaires + réponses sur une session/lecture | Commentez leurs *lectures* | Encouragez, réagissez, recommandez |
| 3 | Profil ami / liste d'amis avec bibliothèques | Votre cercle de *lecteurs* | Leurs livres, leur progression, vos points communs |
| 4 | Listes (sélections partagées) | Des listes à *partager* | Créez vos sélections, inspirez vos amis |
| 5 | Suivi perso (sessions/stats) | Et votre carnet *personnel* | Sessions, statistiques et objectifs de lecture |

Le n°5 garde un rappel du cœur du produit pour ne pas sur-vendre le social.

**Ce qu'il me faut pour rendre les visuels** : 5 captures brutes récentes de ces écrans (≈1206×2622 OK), avec des données crédibles (plusieurs amis dans le feed, un fil de commentaires réel). Je les passe dans le template Playwright et je livre les 1284×2778 dans `appstore_screenshots/cpp_club/`.

## 3. Création dans App Store Connect

1. App LexDay (6760492023) → Fonctionnalités → **Pages produit personnalisées** → « + ».
2. Nom interne : `club-de-lecture`. Uploader les 5 visuels (slot 6,5" : 1284×2778 — ASC refuse 1290×2796 sur cette fiche), coller le texte promo.
3. Soumettre : revue Apple rapide, **sans nouveau binaire**.
4. La CPP a sa propre URL (utilisable aussi ailleurs : bio Insta « on lit ensemble », etc.) et ses propres stats de conversion dans ASC → Analyses.

## 4. Côté Apple Ads (préparé le 30/08)

- Mots-clés `club de lecture` et `défi lecture` **mis en pause** dans leurs groupes actuels (ils brûlaient ~25 € pour 0 nouveau dl).
- Groupe d'annonces dédié **« Club de lecture »** créé **en pause** dans la campagne FR - Generic Exact : exact match `[club de lecture]`, `[défi lecture]`, `[cercle de lecture]`, `[lire ensemble]`, CPT max 1,50 €, Search Match désactivé.
- Dès la CPP approuvée : dans ce groupe → Annonces → créer l'annonce en choisissant la CPP `club-de-lecture` → activer le groupe.

## 5. Mesure et décision

- Échantillon : laisser tourner jusqu'à **~50 taps** sur le groupe (~55 €).
- Succès : conversion tap→install ≥ 15 % (moyenne campagne : 20,8 %). On avait 0 % sur 16 taps.
- Échec (< 8 %) : couper le mot-clé définitivement — le signal serait que ces chercheurs veulent des groupes constitués, pas du social entre amis → décision produit (mini-feature « cercles » sur l'infra sociale existante) avant de rouvrir.
