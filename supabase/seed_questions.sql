-- The question bank starts empty. Add questions here and run this file in
-- the SQL Editor, or add rows in the dashboard's Table Editor.
-- Run it only once at least one row below is filled in; with none it's not
-- valid SQL. Safe to run again: an existing id is updated, not duplicated.
--
-- Columns
--   id            A short unique id you choose, such as 'b-conflict'.
--   text          The question as the interviewer asks it.
--   category      'Common', 'Behavioral' or 'Role-Based'.
--   difficulty    'Easy', 'Medium' or 'Hard'.
--   role          The role it's for, or null for any role.
--   skills        Habits it practises: answerStructure, concreteResults,
--                 tradeoffs.
--   key_points    What a strong answer covers, one checkable statement
--                 each. The answer judge compares answers against these.
--   model_answer  One strong answer, or null.
--
-- Write text values in single quotes and double any apostrophe inside
-- them: 'you''re'. Arrays look like '{answerStructure,tradeoffs}' and
-- '{"First point","Second point"}'.

insert into public.questions (id, text, category, difficulty, role, skills, key_points, model_answer) values

-- ('id', 'Question text', 'Category', 'Difficulty', null, '{skill}', '{"Key point"}', null)

on conflict (id) do update set
  text = excluded.text,
  category = excluded.category,
  difficulty = excluded.difficulty,
  role = excluded.role,
  skills = excluded.skills,
  key_points = excluded.key_points,
  model_answer = excluded.model_answer;
