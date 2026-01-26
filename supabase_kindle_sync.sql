-- Table kindle_sync : stocke les données Reading Insights par utilisateur
create table if not exists public.kindle_sync (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  books_read_this_year integer,
  current_streak integer,
  longest_streak integer,
  total_days_read integer,
  books_data jsonb,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  -- Un seul enregistrement par utilisateur (pour le upsert)
  constraint kindle_sync_user_id_key unique (user_id)
);

-- RLS : chaque utilisateur ne voit que ses propres données
alter table public.kindle_sync enable row level security;

create policy "Users can view own kindle data"
  on public.kindle_sync for select
  using (auth.uid() = user_id);

create policy "Users can insert own kindle data"
  on public.kindle_sync for insert
  with check (auth.uid() = user_id);

create policy "Users can update own kindle data"
  on public.kindle_sync for update
  using (auth.uid() = user_id);
