-- Audit 14/08/2026 : `20260428_add_isbn_to_update_book_metadata.sql` a fait un
-- CREATE OR REPLACE en AJOUTANT un paramètre (p_isbn) → signature différente →
-- Postgres a créé une SECONDE fonction au lieu de remplacer la première.
-- PostgREST ne sait pas résoudre une RPC surchargée : tout appel partiel
-- renvoyait PGRST203 / 300 Multiple Choices. Les deux call-sites côté client
-- (books_service.dart:716 et :1712) sont dans un try/catch qui ne fait qu'un
-- debugPrint → l'enrichissement du catalogue échouait à 100 %, en silence.

drop function if exists public.update_book_metadata(bigint, text, text, integer, text, text, text);

grant execute on function public.update_book_metadata(bigint, text, text, integer, text, text, text, text) to authenticated;
revoke execute on function public.update_book_metadata(bigint, text, text, integer, text, text, text, text) from anon;
