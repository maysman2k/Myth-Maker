-- Migration 001 — Phase 1 identity: unique handles, public profiles,
-- self-service updates with role protection.
--
-- Run AFTER supabase_schema.sql, in the Supabase SQL editor.
-- Also required in the dashboard (not SQL):
--   * Authentication → Sign In / Providers → Email: enable "Confirm email".
--   * Authentication → Providers → Apple: enable, using your app's bundle ID
--     as the client ID (Sign in with Apple capability must be on in Xcode).

-- 1. Unique @handle -----------------------------------------------------

alter table public.profiles
  add column if not exists handle text;

-- Format: 3–20 chars, lowercase letter first, then letters/digits/underscore.
alter table public.profiles
  drop constraint if exists profiles_handle_format;
alter table public.profiles
  add constraint profiles_handle_format
  check (handle is null or handle ~ '^[a-z][a-z0-9_]{2,19}$');

create unique index if not exists profiles_handle_unique
  on public.profiles (lower(handle));

-- 2. Profiles are public (it's a social app) ----------------------------
-- Replaces the own-or-admin read policy so members can see each other and
-- the app can check handle availability.

drop policy if exists "Profiles read own or admin" on public.profiles;
drop policy if exists "Profiles readable by members" on public.profiles;
create policy "Profiles readable by members"
on public.profiles for select
to authenticated
using (true);

-- 3. Users may update their own row — but never their role --------------

drop policy if exists "Profiles update own" on public.profiles;
create policy "Profiles update own"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'Only admins can change roles.';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
before update on public.profiles
for each row execute function public.prevent_role_escalation();

-- 4. Reserved handles ----------------------------------------------------
-- The client blocks these too; the trigger makes it authoritative.

create or replace function public.reject_reserved_handles()
returns trigger
language plpgsql
as $$
begin
  if new.handle is not null and lower(new.handle) in (
    'admin', 'administrator', 'moderator', 'mod', 'support', 'help',
    'brickstudio', 'brick_studio', 'official', 'staff', 'team', 'root',
    'system', 'about', 'settings', 'lego'
  ) then
    raise exception 'That handle is reserved.';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_reserved_handles on public.profiles;
create trigger profiles_reserved_handles
before insert or update on public.profiles
for each row execute function public.reject_reserved_handles();
