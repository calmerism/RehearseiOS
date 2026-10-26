-- Extra columns for the imported question bank (open-interview, MIT).
-- category stays the app's own three groups; area and topic keep the source's
-- finer grouping, so the app can filter by them later.

alter table public.questions
  add column if not exists area text,
  add column if not exists topic text,
  add column if not exists tags text[] not null default '{}',
  add column if not exists explanation text,
  add column if not exists source_url text,
  add column if not exists source_license text;

create index if not exists questions_area on public.questions (area);
create index if not exists questions_role on public.questions (role);
