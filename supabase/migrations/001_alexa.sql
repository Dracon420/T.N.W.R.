-- Alexa linking for T.N.W.R. Run once in the Supabase SQL editor.
--
-- Each app install signs in anonymously (Authentication -> Sign In / Providers
-- -> "Allow anonymous sign-ins" must be ON). To link an Echo, the app gets a
-- short-lived 6-digit code (alexa-code), the user says it to the skill, and
-- the skill redeems it (alexa-pair).

create table if not exists public.alexa_pair_codes (
  code        text primary key,
  app_user    uuid not null references auth.users on delete cascade,
  expires_at  timestamptz not null
);

create table if not exists public.alexa_links (
  app_user       uuid primary key references auth.users on delete cascade,
  alexa_user_id  text not null,
  linked_at      timestamptz not null default now()
);

alter table public.alexa_pair_codes enable row level security;
alter table public.alexa_links enable row level security;

-- Pair codes: no client access at all; only the edge functions (service role).

-- Links: an app install can see and remove its own link, nothing else.
drop policy if exists "read own alexa link" on public.alexa_links;
create policy "read own alexa link" on public.alexa_links
  for select using (auth.uid() = app_user);

drop policy if exists "unlink own alexa" on public.alexa_links;
create policy "unlink own alexa" on public.alexa_links
  for delete using (auth.uid() = app_user);
