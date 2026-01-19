# Migrations Supabase

Ce dossier contient les migrations SQL pour configurer la base de données Supabase.

## Comment appliquer les migrations

### Option 1 : Via l'interface Supabase (Recommandé)

1. Connectez-vous à votre projet Supabase : https://app.supabase.com
2. Allez dans **SQL Editor** dans le menu de gauche
3. Copiez le contenu de chaque fichier de migration dans l'ordre suivant :
   - `fix_books_rls_policies.sql`
   - `fix_user_books_rls_policies.sql`
   - `fix_reading_sessions_rls_policies.sql`
   - `add_streak_badges.sql`
4. Cliquez sur **Run** pour exécuter chaque migration

### Option 2 : Via Supabase CLI

Si vous avez installé Supabase CLI :

```bash
# Se connecter à votre projet
supabase link --project-ref votre-project-ref

# Appliquer toutes les migrations
supabase db push
```

## Description des migrations

### fix_books_rls_policies.sql
Configure les Row Level Security (RLS) policies pour la table `books`.
- Permet à tous les utilisateurs authentifiés de voir et ajouter des livres
- Les livres sont partagés entre tous les utilisateurs

### fix_user_books_rls_policies.sql
Configure les RLS policies pour la table `user_books`.
- Chaque utilisateur ne peut voir et gérer que ses propres livres
- Lie les utilisateurs à leurs livres personnels

### fix_reading_sessions_rls_policies.sql
Configure les RLS policies pour la table `reading_sessions`.
- Les utilisateurs peuvent voir leurs propres sessions
- Les utilisateurs peuvent aussi voir les sessions de leurs amis (pour le feed)
- Chaque utilisateur ne peut modifier que ses propres sessions

### add_streak_badges.sql
Ajoute les badges de streak de lecture dans la table badges.
- 5 badges allant de 1 jour à 30 jours consécutifs

## Ordre d'exécution recommandé

1. D'abord les policies de base (books, user_books, reading_sessions)
2. Ensuite les données (badges)

## Vérification

Après avoir appliqué les migrations, vous pouvez vérifier que tout fonctionne :

```sql
-- Vérifier les policies sur books
SELECT * FROM pg_policies WHERE tablename = 'books';

-- Vérifier les policies sur user_books
SELECT * FROM pg_policies WHERE tablename = 'user_books';

-- Vérifier les policies sur reading_sessions
SELECT * FROM pg_policies WHERE tablename = 'reading_sessions';

-- Vérifier les badges de streak
SELECT * FROM badges WHERE category = 'streak';
```
