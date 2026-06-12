# Rapport — Renommage des badges LexDay

Date : 2026-05-18

## Source

- Dossier source : `/Users/adriencoeffic/wetransfer_image00001-png_2026-05-08_0636/`
- 147 fichiers PNG nommés `image00001.png` à `image00147.png`

## Méthode

Chaque badge porte son nom (titre + sous-titre) directement écrit sur l'image. Identification visuelle par lecture du texte sur chaque PNG, matching avec les 151 IDs du catalogue, écriture du mapping dans `badge_mapping.csv`, puis copie avec renommage vers un nouveau dossier (les originaux sont préservés).

## Résultat

- **147 PNG identifiés et renommés** (1:1, zéro doublon)
- **Copies disponibles dans** : `/Users/adriencoeffic/readon/badges_renamed/`
- **Mapping détaillé** : `/Users/adriencoeffic/readon/badge_mapping.csv`

## Catalogue vs visuels — bilan d'inventaire

Le résumé du catalogue annonce 147 badges mais la somme par catégorie en compte **151**. Avec 147 PNG livrés, **4 badges du catalogue n'ont pas de visuel** :

| ID | Nom | Catégorie |
|---|---|---|
| `comeback_1w` | Semaine Retrouvée | Comeback (7 jours) |
| `comeback_2w` | Lecteur Fidèle | Comeback (14 jours) |
| `comeback_1m` | Le Grand Retour | Comeback (30 jours) |
| `comeback_3m` | Le Phénix Lecteur | Comeback (90 jours) |

À noter : `comeback_2w` (Lecteur Fidèle) porte le **même nom français** que `anniversary_2`. Si tu (re)génères ces 4 visuels, prévois un sous-titre distinctif (ex : "14 jours sans lire" vs "2 ans d'inscription").

## Cas à valider manuellement

### `books_100.png` vs `annual_centenaire.png` — visuels quasi-identiques

Les deux badges portent le titre **"Centenaire"** avec le chiffre **100**. La distinction se fait uniquement sur le sous-titre :

- `books_100.png` (ex-image00051) : titre "Centenaire" + sous-titre **"100 livres"** + pile de 3 livres + grand "100" central
- `annual_centenaire.png` (ex-image00091) : titre "Centenaire" + **pas de sous-titre** + livre unique + petit "100" en haut

L'attribution est cohérente (celle avec le sous-titre "100 livres" → `books_100` qui est lié au compteur cumulé, l'autre → `annual_centenaire`). Mais si tu trouves que ça prête à confusion dans l'app, il faudrait soit régénérer un visuel, soit ajouter un sous-titre "100 livres / an" à `annual_centenaire`.

### `anniversary_2.png` vs `comeback_2w`

Confirmé : `anniversary_2.png` porte le sous-titre **"2 ans d'inscription"**, donc l'attribution est sans ambiguïté côté image. Le badge `comeback_2w` (Lecteur Fidèle / 14 jours) reste à produire.

## Prochaine étape suggérée

Selon `CLAUDE.md` :
> Source de vérité des visuels : `assets/badges/<id>.png` (un seul PNG par badge, pas de variantes `_light`/`_dark`).

Le dossier `/Users/adriencoeffic/readon/assets/badges/` existe et est vide. Pour intégrer les visuels au projet, il suffit de copier les 147 PNG de `badges_renamed/` vers `assets/badges/`, puis de lancer `dart run tool/check_badges.dart` pour vérifier la synchro avec `badges.md`.

Je n'ai pas fait cette copie automatiquement parce que tu voulais peut-être valider d'abord — dis-moi si je peux y aller.
