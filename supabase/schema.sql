-- Rehearse database schema for Supabase.
--
-- Run once in the Supabase dashboard: SQL Editor > New query > paste > Run.
-- Every table has row level security on, so a user can only ever read and
-- write their own rows, even though the app ships with the public anon key.
-- Audio is never stored; transcripts and feedback are, as JSON.

-- Profiles ------------------------------------------------------------------

-- Keeps updated_at current on every change.
create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  target_role text not null default 'Software Engineer',
  experience_level text not null default 'Internship',
  -- Settings from the Profile screen.
  flags_filler_words boolean not null default true,
  reminders_on boolean not null default true,
  -- The Saved collection in order, newest first. Null until the app first
  -- saves it, so a new account starts with the must-practise questions.
  saved_question_ids text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A profile row appears as soon as an account is created, named from the
-- sign-up form.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;

-- Only the database runs it, as a trigger; nobody calls it.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger profiles_touch
  before update on public.profiles
  for each row execute function public.touch_updated_at();

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Real interviews ------------------------------------------------------------

-- Interviews the candidate has scheduled or already had.
create table public.interviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  role text not null,
  company text,
  experience_level text not null,
  interview_type text not null check (interview_type in ('Technical', 'Non-Technical')),
  scheduled_at timestamptz,
  duration_minutes int not null default 20 check (duration_minutes between 5 and 120),
  created_at timestamptz not null default now()
);
create index interviews_user_scheduled on public.interviews (user_id, scheduled_at);

-- Rehearsals -----------------------------------------------------------------

-- One mock interview or practice answer. Feedback keeps each judged part's
-- verdict and evidence, not just the total, so scores can be explained and
-- recomputed later.
create table public.rehearsals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('interview', 'practice')),
  interview_id uuid references public.interviews (id) on delete set null,
  -- The mock's own setup when it isn't for a real interview.
  interview_snapshot jsonb,
  practice_question_id text,
  -- The skill a practice answer was aimed at.
  practice_focus text,
  overall_score int check (overall_score between 0 and 100),
  feedback jsonb,
  transcript jsonb not null default '[]',
  happened_at timestamptz not null default now()
);
create index rehearsals_user_happened on public.rehearsals (user_id, happened_at desc);
create index rehearsals_interview on public.rehearsals (interview_id);

-- Resumes --------------------------------------------------------------------

-- Every resume the candidate has had. One is the Profile's current one;
-- tailored versions point at the resume they were made from.
create table public.resumes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('uploaded', 'built', 'tailored')),
  file_name text not null,
  -- Path in the "resumes" storage bucket, for uploaded files.
  storage_path text,
  -- What was understood: highlights, skills, education.
  context jsonb not null,
  is_current boolean not null default false,
  -- Tailored versions only.
  source_resume_id uuid references public.resumes (id) on delete cascade,
  target_company text,
  target_role text,
  lead text,
  for_interview_id uuid references public.interviews (id) on delete set null,
  created_at timestamptz not null default now()
);
create index resumes_user_created on public.resumes (user_id, created_at desc);
create index resumes_source on public.resumes (source_resume_id);
create index resumes_for_interview on public.resumes (for_interview_id);
-- At most one current Profile resume per user.
create unique index resumes_one_current on public.resumes (user_id) where is_current;

-- Question library -----------------------------------------------------------

-- The shared question bank, readable by every signed-in user. Key points
-- and a model answer give the answer judge something to compare against.
create table public.questions (
  id text primary key,
  text text not null,
  category text not null check (category in ('Common', 'Behavioral', 'Role-Based')),
  difficulty text not null check (difficulty in ('Easy', 'Medium', 'Hard')),
  role text,
  skills text[] not null default '{}',
  key_points text[] not null default '{}',
  model_answer text,
  -- From the imported bank: the source's own grouping, tags and write-up.
  area text,
  topic text,
  tags text[] not null default '{}',
  explanation text,
  source_url text,
  source_license text
);
create index questions_area on public.questions (area);
create index questions_role on public.questions (role);

-- The candidate's own question playlists, questions in the order added.
create table public.playlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  question_ids text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index playlists_user on public.playlists (user_id);

-- Row level security ---------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.interviews enable row level security;
alter table public.rehearsals enable row level security;
alter table public.resumes enable row level security;
alter table public.questions enable row level security;
alter table public.playlists enable row level security;

create policy "Own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Own interviews" on public.interviews
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Own rehearsals" on public.rehearsals
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Own resumes" on public.resumes
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Own playlists" on public.playlists
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- The question bank is read-only from the app; it's edited in the dashboard
-- or by running seed_questions.sql.
create policy "Signed-in users read questions" on public.questions
  for select to authenticated using (true);

-- Resume files -----------------------------------------------------------------

-- A private bucket; each user's files live under a folder named for their id.
insert into storage.buckets (id, name, public) values ('resumes', 'resumes', false);

create policy "Own resume files" on storage.objects
  for all to authenticated
  using (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'resumes' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Deleting an account ------------------------------------------------------------

-- The App Store requires in-app account deletion. Deleting the auth user
-- cascades to every table above. Resume files are removed by the app first.
create function public.delete_account()
returns void
language sql
security definer set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
