-- Feedback style was a profile setting nothing showed or used. Already
-- dropped on the live project (2026-10-23); kept here as the record.
alter table public.profiles drop column if exists feedback_style;
