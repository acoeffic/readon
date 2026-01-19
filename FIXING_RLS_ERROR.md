# 🔧 Correction de l'erreur PostgrestException (Code 42501)

## Problème

Vous rencontrez cette erreur lors de l'ajout d'un livre :
```
PostgrestException(message: new row violates row-level security policy for table "books", code: 42501)
```

## Cause

Les politiques de sécurité (Row Level Security - RLS) de Supabase empêchent l'insertion de nouvelles lignes dans la table `books`.

## Solution : Appliquer les migrations SQL

### Étape 1 : Accéder à Supabase SQL Editor

1. Connectez-vous à https://app.supabase.com
2. Sélectionnez votre projet ReadOn
3. Dans le menu de gauche, cliquez sur **SQL Editor**

### Étape 2 : Exécuter la migration complète

1. Cliquez sur **New query** (nouvelle requête)
2. Copiez-collez **tout le contenu** du fichier suivant :
   ```
   supabase/migrations/00_complete_rls_setup.sql
   ```
3. Cliquez sur **Run** (ou appuyez sur Cmd/Ctrl + Enter)

### Étape 3 : Vérifier que ça fonctionne

Après avoir exécuté la migration, la dernière section affichera toutes les policies créées. Vous devriez voir :

**Pour la table `books` :**
- ✅ Users can view all books (SELECT)
- ✅ Users can insert books (INSERT)
- ✅ Users can update books (UPDATE)

**Pour la table `user_books` :**
- ✅ Users can view their own books (SELECT)
- ✅ Users can insert their own books (INSERT)
- ✅ Users can update their own books (UPDATE)
- ✅ Users can delete their own books (DELETE)

**Pour la table `reading_sessions` :**
- ✅ Users can view their own sessions (SELECT)
- ✅ Users can insert their own sessions (INSERT)
- ✅ Users can update their own sessions (UPDATE)
- ✅ Users can delete their own sessions (DELETE)

### Étape 4 : Tester l'application

1. Relancez votre application Flutter
2. Essayez d'ajouter un nouveau livre
3. L'erreur devrait avoir disparu ! 🎉

## Alternative : Migrations individuelles

Si vous préférez exécuter les migrations une par une, utilisez ces fichiers dans cet ordre :

1. `supabase/migrations/fix_books_rls_policies.sql`
2. `supabase/migrations/fix_user_books_rls_policies.sql`
3. `supabase/migrations/fix_reading_sessions_rls_policies.sql`

## En cas de problème

Si l'erreur persiste après avoir exécuté les migrations :

1. Vérifiez que vous êtes bien connecté avec un utilisateur authentifié
2. Vérifiez dans le SQL Editor que les policies existent :
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'books';
   ```
3. Vérifiez que RLS est activé :
   ```sql
   SELECT tablename, rowsecurity
   FROM pg_tables
   WHERE tablename IN ('books', 'user_books', 'reading_sessions');
   ```
   La colonne `rowsecurity` doit être `true` pour chaque table.

## Support

Si vous avez toujours des problèmes, vérifiez :
- Que vous avez bien copié **tout le contenu** du fichier SQL
- Que la migration s'est exécutée sans erreur
- Que vous êtes connecté avec un compte utilisateur valide dans l'app
