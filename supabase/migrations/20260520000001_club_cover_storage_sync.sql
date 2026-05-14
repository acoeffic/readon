-- Auto-sync club_cover_library avec le bucket storage `asset`,
-- dossier `Image/club_cover/`. À chaque upload d'un fichier dans ce dossier,
-- une row est créée dans club_cover_library. À chaque suppression, la row
-- correspondante passe en is_active = FALSE (on évite de hard-delete pour ne
-- pas casser les groupes qui pointent encore sur l'URL).

-- ── 1. Contrainte unique sur url pour permettre ON CONFLICT ─────────────

ALTER TABLE club_cover_library
  DROP CONSTRAINT IF EXISTS club_cover_library_url_key;

ALTER TABLE club_cover_library
  ADD CONSTRAINT club_cover_library_url_key UNIQUE (url);

-- ── 2. Helper : construit l'URL publique à partir d'un object storage ───

CREATE OR REPLACE FUNCTION public._club_cover_public_url(
  p_bucket TEXT,
  p_name TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_base TEXT;
BEGIN
  -- Tente de récupérer la base via la setting standard de Supabase. Si
  -- absente (instance locale, restore...), on fallback sur le ref hardcodé
  -- du projet courant.
  BEGIN
    v_base := current_setting('app.settings.api_external_url', true);
  EXCEPTION WHEN OTHERS THEN
    v_base := NULL;
  END;
  IF v_base IS NULL OR v_base = '' THEN
    v_base := 'https://nzbhmshkcwudzydeahrq.supabase.co';
  END IF;
  RETURN v_base || '/storage/v1/object/public/' || p_bucket || '/' || p_name;
END;
$$;

-- ── 3. Préfixe surveillé ────────────────────────────────────────────────
-- Mettre à jour si tu changes l'arborescence dans le bucket asset.

CREATE OR REPLACE FUNCTION public._club_cover_path_prefix()
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT 'Image/club_cover/'::TEXT;
$$;

-- ── 4. Extraire un nom human-readable depuis le filename ───────────────

CREATE OR REPLACE FUNCTION public._club_cover_pretty_name(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_basename TEXT;
BEGIN
  -- Garde uniquement le filename (après le dernier /), enlève l'extension
  v_basename := regexp_replace(
    split_part(p_name, '/', array_length(string_to_array(p_name, '/'), 1)),
    '\.[^.]+$',
    ''
  );
  RETURN v_basename;
END;
$$;

-- ── 5. Trigger INSERT : sync upload → table ────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_club_cover_on_storage_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT := _club_cover_path_prefix();
  v_url TEXT;
BEGIN
  IF NEW.bucket_id != 'asset' THEN RETURN NEW; END IF;
  IF NEW.name IS NULL OR NEW.name NOT LIKE v_prefix || '%' THEN
    RETURN NEW;
  END IF;
  -- Filtre : que des images
  IF lower(NEW.name) !~ '\.(png|jpe?g|webp|gif|avif|heic)$' THEN
    RETURN NEW;
  END IF;

  v_url := _club_cover_public_url(NEW.bucket_id, NEW.name);

  INSERT INTO public.club_cover_library (url, name, is_active, sort_order)
  VALUES (v_url, _club_cover_pretty_name(NEW.name), TRUE, 0)
  ON CONFLICT (url) DO UPDATE
    SET is_active = TRUE;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS club_cover_storage_insert_sync ON storage.objects;
CREATE TRIGGER club_cover_storage_insert_sync
AFTER INSERT ON storage.objects
FOR EACH ROW
EXECUTE FUNCTION public.sync_club_cover_on_storage_insert();

-- ── 6. Trigger DELETE : soft-disable quand un fichier disparaît ─────────

CREATE OR REPLACE FUNCTION public.sync_club_cover_on_storage_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prefix TEXT := _club_cover_path_prefix();
  v_url TEXT;
BEGIN
  IF OLD.bucket_id != 'asset' THEN RETURN OLD; END IF;
  IF OLD.name IS NULL OR OLD.name NOT LIKE v_prefix || '%' THEN
    RETURN OLD;
  END IF;

  v_url := _club_cover_public_url(OLD.bucket_id, OLD.name);

  UPDATE public.club_cover_library
     SET is_active = FALSE
   WHERE url = v_url;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS club_cover_storage_delete_sync ON storage.objects;
CREATE TRIGGER club_cover_storage_delete_sync
AFTER DELETE ON storage.objects
FOR EACH ROW
EXECUTE FUNCTION public.sync_club_cover_on_storage_delete();

-- ── 7. Backfill : insère les fichiers déjà présents dans le dossier ─────

INSERT INTO public.club_cover_library (url, name, is_active, sort_order)
SELECT
  _club_cover_public_url(o.bucket_id, o.name),
  _club_cover_pretty_name(o.name),
  TRUE,
  0
FROM storage.objects o
WHERE o.bucket_id = 'asset'
  AND o.name LIKE _club_cover_path_prefix() || '%'
  AND lower(o.name) ~ '\.(png|jpe?g|webp|gif|avif|heic)$'
ON CONFLICT (url) DO UPDATE
  SET is_active = TRUE;
