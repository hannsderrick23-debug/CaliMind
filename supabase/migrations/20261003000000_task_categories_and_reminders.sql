ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_category_check;

ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_category_check
  CHECK (
    category IN (
      'Class Rep',
      'Club President',
      'Study',
      'Work',
      'Health & Fitness',
      'Errands',
      'Family',
      'Finance',
      'Social',
      'Personal'
    )
  );

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS reminder_at timestamptz NULL;
