# Audit des ISBN — listes de lecture recommandées

**Date** : 2026-07-16 · **Périmètre** : les 138 entrées de `lib/data/curated_lists_data.dart` (14 listes)

**Méthode** : lookup inverse de chaque ISBN déclaré (index Google Books via `books.google.com?vid=ISBN:`, OpenLibrary, BnF SRU — l'API `books.googleapis.com` étant inaccessible depuis l'environnement d'audit, quota 429). Chaque ISBN de remplacement a été vérifié individuellement par lookup inverse (fiches éditeurs : Livre de Poche, Gallimard/Folio, Pocket/Lisez, J'ai lu, Points, Actes Sud, Rivages, Minuit, Bourgois…). Toutes les clés de contrôle ISBN-13 validées par calcul.

## Résultat global

**76 entrées sur 138 sont à corriger** (55 %). Les ISBN erronés sont presque tous des ISBN *valides* pointant vers un autre livre du même éditeur — d'où les couvertures aberrantes. Les listes 8 (« Soir de pluie ») et 14 (« Vulgarisation scientifique ») sont parfaites ; les listes 4, 5 et 6 sont fausses à 100 %.

| Liste | À corriger / total |
|---|---|
| 1. Classiques incontournables | 6/10 |
| 2. SF | 8/8 |
| 3. Fierté française | 7/10 |
| 4. Frissons garantis | 10/10 |
| 5. Développement personnel | 10/10 |
| 6. Tour du monde littéraire | 10/10 |
| 7. En moins de 200 pages | 9/10 |
| 8. Soir de pluie | 0/10 ✅ |
| 9. Livres qui font pleurer | 2/10 |
| 10. Fous rires garantis | 1/10 |
| 11. Valise d'été | 3/10 |
| 12. Page-turners | 8/10 |
| 13. Prix Nobel | 2/10 |
| 14. Vulgarisation scientifique | 0/10 ✅ |

## Corrections à appliquer

Colonne « ISBN déclaré = en réalité » : le livre que l'ISBN actuel désigne vraiment (celui dont la couverture s'affichait).

### Liste 1 — Les classiques incontournables

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Le Petit Prince | 9782070368228 | 1984, Orwell (Folio) | **9782070408504** |
| Germinal | 9782070366149 | Fictions, Borges (Folio) | **9782253004226** |
| Le Rouge et le Noir | 9782070411726 | Le Dieu des Petits Riens, Roy (Folio) | **9782253006206** |
| L'Écume des jours | 9782070360871 | Le meurtre et autres nouvelles, Steinbeck | **9782253140870** |
| Les Fleurs du mal | 9782070364015 | Les Chaises, Ionesco (Folio) | **9782253007104** |
| Le Comte de Monte-Cristo | 9782070408504 | Le Petit Prince (Folio 3200) | **9782253196716** (T.1 ; T.2 : 9782253196723) |

OK : L'Étranger, Les Misérables, Madame Bovary, La Peste.

### Liste 2 — SF (8/8 faux)

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Dune | 9782070368228 | 1984, Orwell | **9782266320542** (Pocket 2021) |
| Fahrenheit 451 | 9782070463619 | Cycle de Fondation intégrale T.1 | **9782070415731** (Folio SF) |
| 1984 | 9782072534911 | Ravage, Barjavel (ePub) | **9782070368228** (Folio) |
| Le Meilleur des mondes | 9782070368167 | Rhinocéros, Ionesco | **9782266283038** |
| Fondation | 9782290055984 | D'autres royaumes, Matheson | **9782070360536** (Folio SF) |
| Solaris | 9782070415731 | Fahrenheit 451 (Folio SF) | **9782070468751** |
| Neuromancien | 9782290349229 | Ceux qui vont mourir te saluent, Vargas | **9782290308202** (J'ai lu) |
| La Nuit des temps | 9782253004226 | Germinal, Zola (LdP) | **9782266230919** (Pocket) |

Ironie : l'ISBN déclaré pour « Le Petit Prince »/« Dune » est celui de 1984, celui de « Solaris » est celui de Fahrenheit 451, celui de « La Nuit des temps » est celui de Germinal — plusieurs bons ISBN existent dans le fichier, mais sur les mauvaises lignes.

### Liste 3 — Fierté française

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| À la recherche du temps perdu | 9782070361243 | Dans le café de la jeunesse perdue, Modiano | **9782070379248** (Du côté de chez Swann, T.1, Folio) |
| Le Petit Prince | 9782070368228 | 1984, Orwell | **9782070408504** |
| Les Trois Mousquetaires | 9782253002468 | *(ISBN inexistant)* | **9782253008880** (LdP) |
| Voyage au bout de la nuit | 9782070366026 | Bourlinguer, Cendrars | **9782070360284** (Folio) |
| Bel-Ami | 9782070364329 | Derrière chez Martin, Aymé | **9782253009009** (LdP) |
| Germinal | 9782070366149 | Fictions, Borges | **9782253004226** |
| L'Écume des jours | 9782070360871 | Le meurtre…, Steinbeck | **9782253140870** |

OK : L'Étranger, Madame Bovary, Les Misérables.

### Liste 4 — Frissons garantis (10/10 faux)

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| La Vérité sur l'affaire Harry Quebert | 9782253176787 | Les jumeaux de Black Hill, Chatwin | **9782889730087** (Rosie & Wolfe poche) |
| Les Rivières pourpres | 9782266219181 | Georges et les secrets de l'univers, Hawking | **9782253171676** (LdP) |
| La Fille du train | 9782253237341 | De sel et de sang, Mina | **9782266254489** (Pocket) |
| Da Vinci Code | 9782253151531 | Rose Madder, King | **9782253001171** (LdP intégral) |
| Ne le dis à personne | 9782020386142 | *(inexistant)* | **9782266207706** (Pocket) |
| Millénium 1 | 9782253157687 | Toute passion abolie, Sackville-West | **9782330004996** (Babel noir) |
| Gone Girl | 9782266233934 | La petite fêlée aux allumettes, Monfils | **9782253164913** (« Les Apparences », LdP) |
| Le Silence des agneaux | 9782253083146 | La trilogie du Tearling, Johansen | **9782266208949** (Pocket) |
| Chanson douce | 9782226320797 | Chef de guerre T.1, Clancy | **9782072764929** (Folio) |
| Pars vite et reviens tard | 9782070408745 | *(inexistant)* | **9782290349311** (J'ai lu) |

### Liste 5 — Développement personnel (10/10 faux)

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Atomic Habits | 9782266289160 | Entrez dans la danse, Teulé | **9782035969200** (« Un rien peut tout changer », Larousse) |
| L'Art subtil de s'en foutre | 9782081375635 | 30 ans de débats, coll. | **9782212567595** (Eyrolles) |
| Père riche, père pauvre | 9782290345566 | *(inexistant)* | **9782892259551** (Un monde différent) |
| Le Pouvoir du moment présent | 9782253085348 | Dictionnaire de la langue française | **9782290020203** (J'ai lu) |
| Les 7 habitudes… | 9782290200582 | *(inexistant)* | **9782290206058** (J'ai lu) |
| Pensées pour moi-même | 9782253087816 | Contes en prose, Perrault | **9782080700162** (GF Flammarion) |
| Influence et manipulation | 9782081404809 | *(inexistant)* | **9782266227926** (Pocket) |
| Ikigai | 9782266282536 | *(inexistant)* | **9782266286688** (Pocket) |
| L'Alchimiste | 9782253004011 | Les Liaisons dangereuses, Laclos | **9782290258064** (J'ai lu 2021) |
| Sapiens | 9782253067900 | La Végétarienne, Han Kang | **9782253091752** (LdP — même ISBN que liste 14, correct) |

### Liste 6 — Tour du monde littéraire (10/10 faux)

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Cent ans de solitude | 9782070360536 | Fondation, Asimov (Folio SF) | **9782020238113** (Points) |
| Le Dieu des petits riens | 9782253933090 | Les crabes de la mer du Nord, Brecht | **9782070411726** (Folio — l'ISBN déclaré pour « Le Rouge et le Noir » liste 1 !) |
| Mémoires d'une geisha | 9782253004226 | Germinal, Zola | **9782253117957** (« Geisha », LdP) |
| Les Cerfs-volants de Kaboul | 9782264052575 | L'écrivain et l'autre, Liscano | **9782264043573** (10/18) |
| Le Parfum | 9782070793723 | Où est le pouvoir ?, coll. | **9782253044901** (LdP) |
| La Maison aux esprits | 9782253151128 | La peau de Sharon, Wood | **9782253038047** (LdP) |
| L'Amant | 9782070368747 | *(inexistant / autre)* | **9782707306951** (Minuit) |
| Le Livre de l'intranquillité | 9782070414550 | Le moine, Artaud/Lewis | **9782267021776** (Bourgois, éd. intégrale) |
| Le Vieil Homme et la mer | 9782253002567 | *(inexistant)* | **9782070360079** (Folio) |
| L'Amour aux temps du choléra | 9782070360581 | La mort dans l'âme, Sartre | **9782253060543** (LdP) |

### Liste 7 — En moins de 200 pages (9/10 faux)

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Le Petit Prince | 9782070368228 | 1984, Orwell | **9782070408504** |
| La Métamorphose | 9782070364930 | Journal du voleur, Genet | **9782070462872** (Folio classique) |
| Candide | 9782070402489 | Nos séparations, Foenkinos | **9782070466634** (Folio classique) |
| Le Vieil Homme et la mer | 9782070369218 | Mémoires d'Hadrien, Yourcenar | **9782070360079** (Folio) |
| L'Appel de la forêt | 9782070367825 | Le Paysan de Paris, Aragon | **9782072847134** (Folio) |
| La Perle | 9782070364657 | Paris est une fête, Hemingway | **9782070364282** (Folio) |
| Le Prophète | 9782253004585 | Pliez bagage, Christie | **9782253064091** (LdP) |
| La Chute | 9782070360758 | Les Nouveaux prêtres, Saint Pierre | **9782070360109** (Folio) |
| L'Amant | 9782070368747 | *(autre)* | **9782707306951** (Minuit) |

OK : L'Étranger.

### Liste 8 — Soir de pluie : ✅ 10/10 corrects

### Liste 9 — Livres qui font pleurer

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Les Cerfs-volants de Kaboul | 9782264052575 | L'écrivain et l'autre, Liscano | **9782264043573** |
| Le Petit Prince | 9782070368228 | 1984, Orwell | **9782070408504** |

OK : les 8 autres.

### Liste 10 — Fous rires garantis

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Bel-Ami | 9782070364329 | Derrière chez Martin, Aymé | **9782253009009** |

OK : les 9 autres.

### Liste 11 — Valise d'été

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| L'Alchimiste | 9782253004011 | Les Liaisons dangereuses | **9782290258064** |
| La Vérité sur l'affaire Harry Quebert | 9782253176787 | Les jumeaux de Black Hill | **9782889730087** |
| Millénium 1 | 9782253157687 | Toute passion abolie | **9782330004996** |

OK : les 7 autres (dont Big Little Lies — l'ISBN pointe vers « Petits secrets, grands mensonges », le titre français : correct).

### Liste 12 — Page-turners

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Gone Girl | 9782266233934 | La petite fêlée aux allumettes | **9782253164913** |
| Da Vinci Code | 9782253151531 | Rose Madder, King | **9782253001171** |
| Shutter Island | 9782743620066 | *(inexistant)* | **9782743614812** (Rivages/Noir) |
| La Fille du train | 9782253237341 | De sel et de sang | **9782266254489** |
| Dune | 9782070368228 | 1984, Orwell | **9782266320542** |
| Ne le dis à personne | 9782020386142 | *(inexistant)* | **9782266207706** |
| Le Comte de Monte-Cristo | 9782070408504 | Le Petit Prince | **9782253196716** |
| Le Parfum | 9782070793723 | Où est le pouvoir ? | **9782253044901** |

OK : Divergente, Rebecca.

### Liste 13 — Prix Nobel

| Titre | ISBN déclaré | En réalité | ISBN corrigé |
|---|---|---|---|
| Cent ans de solitude | 9782070360536 | Fondation, Asimov | **9782020238113** |
| Le Vieil Homme et la Mer | 9782253002567 | *(inexistant)* | **9782070360079** |

OK : les 8 autres (dont La Végétarienne — 9782253067900 est correct… c'est l'ISBN déclaré à tort pour « Sapiens » en liste 5).

### Liste 14 — Vulgarisation scientifique : ✅ 10/10 corrects

## Notes

- **Cohérence inter-listes** : chaque livre présent dans plusieurs listes reçoit le même ISBN corrigé (Petit Prince, Harry Quebert, Millénium, Gone Girl, Da Vinci Code, Dune, Monte-Cristo, Vieil Homme, L'Amant, Cerfs-volants, Parfum, Germinal, Bel-Ami, Alchimiste, Cent ans de solitude, Écume des jours, Sapiens).
- **Œuvres multi-tomes** : Monte-Cristo, la Recherche et Les Trois Mousquetaires → ISBN du tome 1.
- **Titres français** : Gone Girl → « Les Apparences », Atomic Habits → « Un rien peut tout changer », Mémoires d'une geisha → « Geisha ». Les couvertures afficheront ces titres.
- Le suivi « lu/pas lu » (`user_curated_book_reads`) étant keyé par ISBN, changer les ISBN **réinitialise les coches** des utilisateurs existants. Migration possible : `UPDATE user_curated_book_reads SET book_isbn = <nouveau> WHERE book_isbn = <ancien> AND list_id = <id>`.
- Le correctif code déjà en place (validation titre/auteur) reste utile en défense même après correction des données.
