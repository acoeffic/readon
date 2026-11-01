-- Rappel de mise à jour (bannière douce, dismissible) : version publiée par
-- plateforme, lue au démarrage de l'app et comparée à PackageInfo.version.
-- Table backend-only (RLS deny-all), lecture uniquement via la RPC
-- SECURITY DEFINER — même pattern que trending_curated.
--
-- Mise à jour manuelle après chaque publication store :
--   update public.app_versions set latest_version = '1.2.3', store_url = '...'
--   where platform = 'ios';

create table if not exists public.app_versions (
  platform text primary key check (platform in ('ios', 'android')),
  latest_version text not null,
  store_url text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_versions enable row level security;
revoke all on table public.app_versions from anon, authenticated;

create or replace function public.get_app_version_info(p_platform text)
returns table (latest_version text, store_url text)
language sql
stable
security definer
set search_path = public
as $$
  select av.latest_version, av.store_url
  from public.app_versions av
  where av.platform = p_platform;
$$;

grant execute on function public.get_app_version_info(text) to anon, authenticated;

-- Seed avec les versions actuellement en ligne — À VÉRIFIER/CORRIGER avant
-- la prochaine publication (voir App Store Connect / Play Console).
insert into public.app_versions (platform, latest_version, store_url)
values
  ('ios', '1.0.8', 'https://apps.apple.com/fr/app/lexday/id6760492023'),
  ('android', '1.0.5', 'https://play.google.com/store/apps/details?id=com.acoeffic.lexday')
on conflict (platform) do nothing;
