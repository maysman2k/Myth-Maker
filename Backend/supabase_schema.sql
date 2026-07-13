-- BrickStudio Supabase schema
-- Run this in Supabase Dashboard > SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email text not null,
  role text not null default 'user' check (role in ('user', 'moderator', 'editor', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.articles (
  id uuid primary key,
  title text not null,
  slug text not null,
  summary text not null,
  body_markdown text not null,
  category text not null,
  tags text[] not null default '{}',
  author_name text not null,
  sources jsonb not null default '[]'::jsonb,
  is_rumour boolean not null default false,
  ai_assisted boolean not null default false,
  comments_enabled boolean not null default true,
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'published', 'archived')),
  like_count integer not null default 0,
  view_count integer not null default 0,
  read_time_minutes integer not null default 1,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  hero_image_url text,
  gallery_image_urls text[],
  media_urls text[]
);

create table if not exists public.story_submissions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  summary text not null,
  body_markdown text not null,
  category text not null,
  tags text[] not null default '{}',
  image_references text[] not null default '{}',
  media_references text[] not null default '{}',
  links jsonb not null default '[]'::jsonb,
  is_rumour boolean not null default false,
  ai_assisted boolean not null default false,
  status text not null default 'pendingReview' check (status in ('pendingReview', 'changesRequested', 'published', 'locked')),
  decline_count integer not null default 0,
  latest_feedback text,
  published_article_id uuid references public.articles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz not null default now()
);

insert into storage.buckets (id, name, public)
values ('story-media', 'story-media', true)
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.articles enable row level security;
alter table public.story_submissions enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

drop policy if exists "Profiles read own or admin" on public.profiles;
create policy "Profiles read own or admin"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists "Profiles insert own" on public.profiles;
create policy "Profiles insert own"
on public.profiles for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "Published articles readable" on public.articles;
create policy "Published articles readable"
on public.articles for select
to anon, authenticated
using (status = 'published' or public.is_admin());

drop policy if exists "Admins manage articles" on public.articles;
create policy "Admins manage articles"
on public.articles for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Users read own submissions admins read all" on public.story_submissions;
create policy "Users read own submissions admins read all"
on public.story_submissions for select
to authenticated
using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Users insert own submissions" on public.story_submissions;
create policy "Users insert own submissions"
on public.story_submissions for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "Users update editable own submissions" on public.story_submissions;
create policy "Users update editable own submissions"
on public.story_submissions for update
to authenticated
using (user_id = auth.uid() and status in ('pendingReview', 'changesRequested') and decline_count < 3)
with check (user_id = auth.uid() and status = 'pendingReview' and decline_count < 3);

drop policy if exists "Admins manage submissions" on public.story_submissions;
create policy "Admins manage submissions"
on public.story_submissions for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Story media public read" on storage.objects;
create policy "Story media public read"
on storage.objects for select
to anon, authenticated
using (bucket_id = 'story-media');

drop policy if exists "Authenticated users upload story media" on storage.objects;
create policy "Authenticated users upload story media"
on storage.objects for insert
to authenticated
with check (bucket_id = 'story-media' and auth.uid()::text = (storage.foldername(name))[1]);

-- Community layer: build posts + weekly game leaderboard ---------------------

create table if not exists community_posts (
  id uuid primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  caption text not null default '',
  image_references text[] not null default '{}',
  challenge_id uuid,
  thread_id uuid,
  thread_day int,
  status text not null default 'visible',
  report_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table community_posts enable row level security;
create policy "community posts are readable" on community_posts
  for select using (status <> 'removed');
create policy "users insert own posts" on community_posts
  for insert with check (auth.uid() = user_id);
create policy "users update own posts" on community_posts
  for update using (auth.uid() = user_id);

create table if not exists game_scores (
  id uuid primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  display_name text not null,
  game text not null,
  score int not null,
  week_key text not null,
  updated_at timestamptz not null default now(),
  unique (user_id, game, week_key)
);

alter table game_scores enable row level security;
create policy "scores are readable" on game_scores
  for select using (true);
create policy "users write own scores" on game_scores
  for insert with check (auth.uid() = user_id);
create policy "users update own scores" on game_scores
  for update using (auth.uid() = user_id);
