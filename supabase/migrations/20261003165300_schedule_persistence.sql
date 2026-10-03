CREATE TABLE IF NOT EXISTS public.schedule_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  schedule_date date NOT NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.schedule_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "schedule_user_only" ON public.schedule_blocks;
DROP POLICY IF EXISTS "schedule_select_own" ON public.schedule_blocks;
DROP POLICY IF EXISTS "schedule_insert_own" ON public.schedule_blocks;
DROP POLICY IF EXISTS "schedule_update_own" ON public.schedule_blocks;
DROP POLICY IF EXISTS "schedule_delete_own" ON public.schedule_blocks;

CREATE POLICY "schedule_select_own" ON public.schedule_blocks
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "schedule_insert_own" ON public.schedule_blocks
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "schedule_update_own" ON public.schedule_blocks
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "schedule_delete_own" ON public.schedule_blocks
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.schedule_blocks TO authenticated;

CREATE INDEX IF NOT EXISTS schedule_blocks_user_date_start_idx
  ON public.schedule_blocks(user_id, schedule_date, start_time);
