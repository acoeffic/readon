# Spec — Suggestion cadeau (« Quel livre offrir à un(e) ami(e) ? »)

> Spec de conception, aucun code. Alignée sur l'existant : Edge Function `ai-chat` (Muse), `ai-suggest-books` v16, tables `friends`, `book_ratings`, `user_books`, `ai_usage`, et la logique de visibilité de `get_friend_profile_v2`.

## 1. Principe

Dans Muse, l'utilisateur écrit « C'est l'anniversaire d'Alizée, quel livre je pourrais lui offrir ? ». Muse identifie l'amie, récupère **ce que l'utilisateur a le droit de voir** de ses lectures (livres visibles + notes publiques), et propose 3 idées cadeaux argumentées — en excluant tout ce qu'Alizée a déjà dans sa bibliothèque.

Décisions produit (validées le 02/08/2026) :

- **Point d'entrée : Muse (chat)** — pas de bouton sur le profil ami en v1.
- **Gating : gratuit limité** — 2 suggestions cadeaux / mois en free, illimité en premium.
- Une **spec avant le code** (ce document).

## 2. Architecture — function calling dans `ai-chat`

`ai-chat` ne sait faire aujourd'hui que du chat « contexte + historique → réponse ». On lui ajoute le **tool calling OpenAI** avec un seul outil :

```
suggest_gift_books(friend_name: string, count?: number = 3)
```

Flux d'une requête :

1. Appel OpenAI habituel, avec en plus `tools: [suggest_gift_books]` et, dans le prompt système, la consigne : « si l'utilisateur cherche un livre à OFFRIR à quelqu'un, appelle l'outil avec le prénom mentionné ».
2. Si le modèle répond par un `tool_call` → le serveur exécute l'outil (résolution de l'ami + construction du contexte cadeau, §3-4), renvoie le résultat comme message `tool`, et rappelle OpenAI **une seule fois** (pas de boucle) pour produire la réponse finale.
3. Sinon, comportement inchangé (aucune régression pour les conversations normales).

La réponse finale reste un message Muse classique, au format déjà parsé par l'app (`"Titre exact" de Auteur exact`) → les titres restent cliquables sans changement côté Flutter.

**Pourquoi pas une Edge Function séparée `ai-suggest-gift` ?** Le point d'entrée choisi est conversationnel : c'est Muse qui doit comprendre « pour Alizée », gérer l'ambiguïté (« j'ai deux amies Marie »), et enchaîner (« plutôt un roman » → relance dans le même fil). Le tool calling donne tout ça gratuitement. Une fonction séparée redeviendrait pertinente si on ajoute un bouton profil ami en v2 (elle pourra alors extraire le builder de contexte, voir §8).

## 3. Résolution de l'ami

Entrée : `friend_name` en texte libre (« Alizée », « alizee », « Ali »).

1. Charger les amis **acceptés** de l'appelant (`friends.status = 'accepted'`, dans les deux sens).
2. Exclure toute paire présente dans `user_blocks` (même règle que `get_friend_profile_v2`).
3. Matcher `profiles.display_name` insensible à la casse **et aux accents** (unaccent côté SQL ou normalisation côté Deno) : exact d'abord, puis préfixe.
4. Résultats :
   - **1 match** → on continue.
   - **0 ou plusieurs** → l'outil renvoie la liste des candidats (display_name uniquement) ou une liste vide ; Muse demande une précision (« Tu as deux amies qui s'appellent Marie… »). Ce tour ne consomme **pas** de crédit cadeau.
   - Personne du nom demandé n'est ami → même réponse que 0 match (« je ne trouve pas X parmi tes amis ») ; ne jamais révéler qu'un compte existe (pas de différence bloqué / inexistant / non-ami).

## 4. Contexte cadeau — règle de visibilité (le point critique)

`ai-chat` interroge la base en **service role** (bypass RLS) : la restriction doit être **explicite dans les requêtes**. Règle unique : *le contexte envoyé à OpenAI ne contient que ce que l'appelant peut déjà voir dans l'app*, c'est-à-dire exactement la sémantique de `get_friend_profile_v2` :

| Donnée de l'ami | Incluse dans le contexte ? | Condition |
|---|---|---|
| Livres terminés / en cours / abandonnés | ✅ (30 max, plus récents d'abord) | `user_books.is_hidden = FALSE` |
| Notes, `would_recommend`, `emotion_tags` | ✅ signal n°1 | `book_ratings.is_public = TRUE` **et** lecture non cachée (join `user_book_id`) |
| `review_text` | ✅ tronqué à 100 car. | idem (public) |
| Notes **privées** (`is_public = FALSE`) | ❌ jamais | — |
| Liste à lire (`to_read`) | ❌ en positif (wishlist privée, non exposée dans l'app) | sert **uniquement** à l'exclusion |
| Livres cachés (`is_hidden = TRUE`) | ❌ dans le contexte | servent **uniquement** à l'exclusion |
| Genres dominants, longueur moyenne | ✅ calculés sur les livres visibles | même agrégats qu'`ai-suggest-books` |

**Liste d'exclusion** (transmise comme « NE JAMAIS proposer ») : *tous* les `user_books` de l'ami, **tous statuts confondus, cachés et `to_read` inclus**. L'exclusion ne fuit rien (les titres n'apparaissent jamais dans la réponse) et évite le pire cadeau possible : un livre qu'elle a déjà.

Prompt de l'étape finale : réutiliser la stratégie d'`ai-suggest-books` v16 (notes = signal prioritaire, ≤ 2★ et abandons = à éviter, tags émotionnels = expérience recherchée) reformulée « cadeau » : le destinataire n'est pas le lecteur ; proposer 3 idées avec pour chacune une raison formulée *offrable* (« parce qu'elle a adoré X… »). Mentionner que les raisons ne doivent s'appuyer que sur les infos fournies (pas d'invention sur les goûts de l'amie).

Cas « rien à voir » : ami sans livre visible ni note publique → l'outil renvoie `no_visible_data` ; Muse l'explique gentiment et suggère de demander à l'ami de rendre ses notes publiques (nudge viral) ou de décrire ses goûts à la main dans le chat.

## 5. Quotas (gratuit limité)

- Nouveau feature key dans `ai_usage` : **`gift_suggest`**, plafond **2 / mois** pour les free, illimité premium — même pattern exact qu'`ai-suggest-books` (`MAX_FREE_MONTHLY_*` + count sur le mois courant, check *avant* l'appel OpenAI final, insert *après* un appel réussi).
- Un tour de désambiguïsation (0 ou N matchs, §3) ne consomme rien.
- Le message reste par ailleurs soumis au quota Muse existant (3 messages/mois free) : pas de code en plus, mais **à trancher à l'implémentation** : exempter ou non les messages-cadeaux du compteur Muse. Recommandation : ne pas exempter en v1 (simple), et si la feature marche, en faire un argument premium.
- Dépassement → réponse `limit_reached` renvoyée **comme message Muse normal** (pas un code d'erreur HTTP qui casserait le fil de conversation), avec l'invitation premium habituelle.

## 6. UI Flutter (minimal en v1)

- **Chip de démarrage** dans `ai_chat_page.dart`, à côté des prompts suggérés existants : « 🎁 Un livre à offrir » → insère le gabarit « Quel livre offrir à … ? » (l'utilisateur tape le prénom). Clé l10n neutre, FR/EN.
- Aucun autre changement : la réponse est un message Muse standard, titres cliquables via le parsing existant.
- Affichage du quota : réutiliser le pattern `remaining` renvoyé dans la réponse (comme `summarize-passage`) si on veut afficher « 1 suggestion cadeau restante ce mois-ci » — optionnel v1.

## 7. Points d'attention techniques

1. ⚠️ **Le repo est désynchronisé du déployé** : `supabase/functions/ai-chat/index.ts` (repo) ≠ v20 déployée (gpt-4o-mini + retry/backoff + timeout 30 s, mais contexte *sans* signaux d'engagement) ; le repo contient au contraire le contexte enrichi + gpt-4o sans retry. **Avant toute modif : rapatrier la v20 déployée dans le repo** (via MCP `get_edge_function`), y re-porter le contexte enrichi si souhaité, puis développer par-dessus. Même remarque pour `ai-suggest-books` (repo ≠ v16).
2. Le tool calling doit conserver le **retry/backoff** existant (`callOpenAIWithRetry`) pour les deux appels OpenAI (celui qui déclenche le tool et l'appel final).
3. Historique : stocker dans `ai_messages` uniquement le message utilisateur et la réponse finale (pas les messages `tool` intermédiaires) — le schéma actuel (`role`, `content`) reste inchangé ; le contexte cadeau est reconstruit à chaque requête.
4. `verify_jwt = true` inchangé (appel authentifié depuis l'app, pas un webhook — cf. feedback_supabase_edge_jwt).
5. Si une migration SQL est nécessaire (elle ne devrait pas l'être : aucune table nouvelle), penser au durcissement RLS du 22/07 : GRANT explicites, rien pour `anon`.
6. Coût : 2 appels OpenAI par suggestion (tool + final). Garder gpt-4o-mini pour le tour de déclenchement ; le tour final peut passer sur gpt-4o si la qualité des recos le justifie (aligné sur `ai-suggest-books`).

## 8. V2 (hors scope v1, notées pour plus tard)

- **Bouton « 🎁 Idées cadeaux » sur le profil ami** → extraire le builder de contexte cadeau dans un module partagé, exposé aussi par une fonction dédiée.
- **Rappel d'anniversaire** (« c'est bientôt l'anniv d'Alizée 🎂 ») : nécessite un champ date d'anniversaire dans `profiles` (n'existe pas aujourd'hui) + opt-in de partage — à spécifier séparément.
- **Wishlist publique** : laisser un utilisateur rendre sa liste `to_read` visible de ses amis (flag par livre ou global) — transformerait le meilleur signal cadeau en donnée utilisable en positif.
- Partage de la suggestion (« envoyer l'idée à un autre ami »).

## 9. Ordre d'implémentation suggéré

1. Resynchroniser `ai-chat` (et `ai-suggest-books`) repo ↔ déployé.
2. `ai-chat` : squelette tool calling (sans régression chat normal) + outil `suggest_gift_books` (résolution ami §3 + contexte §4 + quota §5). Testable via curl avant toute UI.
3. Chip « 🎁 Un livre à offrir » + l10n.
4. Redéploiement + test de bout en bout avec un vrai couple d'amis (dont : ami sans données visibles, prénom ambigu, quota atteint).

Chaque étape est shippable ; la valeur existe dès l'étape 2 (la phrase libre suffit, la chip n'est que de la découvrabilité).
