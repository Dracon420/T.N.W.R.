-- Photo approval by a chosen person. Run once in the Supabase SQL editor,
-- after 001_alexa.sql.
--
-- The app uploads the photo (approval-create); the approver opens a link to
-- the approval page (docs/approve/index.html on GitHub Pages), which reads
-- and decides through the "approval" function using a secret token.

create table if not exists public.photo_approvals (
  id             uuid primary key default gen_random_uuid(),
  token          text not null,
  app_user       uuid not null references auth.users on delete cascade,
  task_title     text not null,
  approver_name  text not null,
  photo_path     text,
  status         text not null default 'pending'
                 check (status in ('pending', 'approved', 'rejected')),
  note           text,
  created_at     timestamptz not null default now(),
  decided_at     timestamptz
);

alter table public.photo_approvals enable row level security;

-- The app can check on its own requests (never the token-less rows of others).
drop policy if exists "read own approvals" on public.photo_approvals;
create policy "read own approvals" on public.photo_approvals
  for select using (auth.uid() = app_user);

-- Private bucket: photos are only reachable through short-lived signed links
-- handed out by the "approval" function.
insert into storage.buckets (id, name, public)
values ('proof-photos', 'proof-photos', false)
on conflict (id) do nothing;
