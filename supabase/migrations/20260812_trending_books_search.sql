-- Tendances pour la recherche manuelle de livres (appliquée le 2026-08-12 via MCP)
-- NB : get_trending_books(integer) existe déjà (suggestions) — on crée get_trending_books_for_search.
-- 1) Table curée de bestsellers externes (fallback quand la communauté est trop petite)
-- 2) RPC get_trending_books_for_search : communauté 30j + complément curé,
--    exclut les livres déjà dans la bibliothèque de l'appelant
-- 3) RPC get_books_popularity : nb de lecteurs par google_id/isbn pour booster
--    le tri des résultats de recherche

create table if not exists public.trending_curated (
  id bigint generated always as identity primary key,
  title text not null,
  author text not null,
  google_id text,
  isbn text,
  cover_url text,
  page_count integer,
  published_date text,
  position integer not null default 100,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Backend-only : RLS deny-all, lecture uniquement via la RPC SECURITY DEFINER
alter table public.trending_curated enable row level security;
revoke all on table public.trending_curated from anon, authenticated;

create or replace function public.get_trending_books_for_search(p_limit integer default 12)
returns table (
  book_id bigint,
  google_id text,
  title text,
  author text,
  cover_url text,
  isbn text,
  page_count integer,
  published_date text,
  description text,
  readers_count bigint,
  source text
)
language sql
stable
security definer
set search_path = public
as $$
with lim as (
  select least(greatest(coalesce(p_limit, 12), 1), 30) as n
),
mine as (
  select ub.book_id
  from user_books ub
  where ub.user_id = auth.uid()
),
community as (
  select b.id as book_id,
         b.google_id, b.title, b.author, b.cover_url, b.isbn,
         b.page_count, b.published_date, b.description,
         count(distinct ub.user_id)::bigint as readers_count
  from user_books ub
  join books b on b.id = ub.book_id
  where ub.created_at > now() - interval '30 days'
    and coalesce(ub.is_hidden, false) = false
    and b.id not in (select book_id from mine)
  group by b.id
  having count(distinct ub.user_id) >= 2
),
curated as (
  select b.id as book_id,
         coalesce(tc.google_id, b.google_id) as google_id,
         tc.title,
         tc.author,
         coalesce(tc.cover_url, b.cover_url) as cover_url,
         coalesce(tc.isbn, b.isbn) as isbn,
         coalesce(tc.page_count, b.page_count) as page_count,
         coalesce(tc.published_date, b.published_date) as published_date,
         b.description,
         0::bigint as readers_count,
         tc.position
  from trending_curated tc
  left join books b
    on (tc.google_id is not null and b.google_id = tc.google_id)
    or (tc.isbn is not null and b.isbn = tc.isbn)
    or (lower(b.title) = lower(tc.title) and lower(coalesce(b.author, '')) = lower(tc.author))
  where tc.active
    and (b.id is null or b.id not in (select book_id from mine))
    and not exists (
      select 1 from community c
      where (c.google_id is not null and c.google_id = coalesce(tc.google_id, b.google_id))
         or (c.isbn is not null and c.isbn = coalesce(tc.isbn, b.isbn))
         or (lower(c.title) = lower(tc.title))
    )
),
merged as (
  select book_id, google_id, title, author, cover_url, isbn, page_count,
         published_date, description, readers_count,
         'community'::text as source,
         1 as bucket,
         (-readers_count)::numeric as ord
  from community
  union all
  select book_id, google_id, title, author, cover_url, isbn, page_count,
         published_date, description, readers_count,
         'bestseller'::text as source,
         2 as bucket,
         position::numeric as ord
  from curated
)
select book_id, google_id, title, author, cover_url, isbn, page_count,
       published_date, description, readers_count, source
from merged, lim
order by bucket, ord
limit (select n from lim);
$$;

revoke all on function public.get_trending_books_for_search(integer) from public, anon;
grant execute on function public.get_trending_books_for_search(integer) to authenticated;

create or replace function public.get_books_popularity(
  p_google_ids text[] default '{}',
  p_isbns text[] default '{}'
)
returns table (
  google_id text,
  isbn text,
  readers_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select b.google_id, b.isbn, count(distinct ub.user_id)::bigint as readers_count
  from books b
  join user_books ub on ub.book_id = b.id
  where (b.google_id = any(coalesce(p_google_ids, '{}')) or b.isbn = any(coalesce(p_isbns, '{}')))
    and coalesce(array_length(p_google_ids, 1), 0) <= 40
    and coalesce(array_length(p_isbns, 1), 0) <= 40
  group by b.id;
$$;

revoke all on function public.get_books_popularity(text[], text[]) from public, anon;
grant execute on function public.get_books_popularity(text[], text[]) to authenticated;

-- Seed initial : top ventes France (Edistat, semaine du 27/07 au 02/08/2026),
-- déjà inséré en prod le 2026-08-12. Les lignes sans google_id/isbn sont
-- résolues à la volée côté app (Google Books) et enrichies via la table books.
