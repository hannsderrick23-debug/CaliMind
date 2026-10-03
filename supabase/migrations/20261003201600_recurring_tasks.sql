ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS recurrence_rule text
    CHECK (recurrence_rule IS NULL OR recurrence_rule IN ('daily', 'weekly')),
  ADD COLUMN IF NOT EXISTS recurrence_source_id uuid
    REFERENCES public.tasks(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS tasks_recurrence_source_id_uidx
  ON public.tasks (recurrence_source_id)
  WHERE recurrence_source_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.complete_task(
  p_task_id uuid,
  p_completed boolean
)
RETURNS SETOF public.tasks
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_task public.tasks%ROWTYPE;
  v_interval_days integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required'
      USING ERRCODE = '42501';
  END IF;

  SELECT *
    INTO v_task
    FROM public.tasks
   WHERE id = p_task_id
     AND user_id = auth.uid()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found or not owned by the current user'
      USING ERRCODE = '42501';
  END IF;

  IF p_completed AND NOT v_task.completed THEN
    UPDATE public.tasks
       SET completed = true,
           completed_at = now(),
           updated_at = now()
     WHERE id = p_task_id
     RETURNING * INTO v_task;

    IF v_task.recurrence_rule IS NOT NULL THEN
      v_interval_days := CASE v_task.recurrence_rule
        WHEN 'daily' THEN 1
        WHEN 'weekly' THEN 7
      END;

      INSERT INTO public.tasks (
        user_id,
        title,
        description,
        category,
        duration,
        deadline,
        preferred_time,
        specific_time,
        priority,
        recurrence_rule,
        recurrence_source_id
      )
      VALUES (
        v_task.user_id,
        v_task.title,
        v_task.description,
        v_task.category,
        v_task.duration,
        CASE
          WHEN v_task.deadline IS NULL THEN NULL
          ELSE v_task.deadline + make_interval(days => v_interval_days)
        END,
        v_task.preferred_time,
        v_task.specific_time,
        v_task.priority,
        v_task.recurrence_rule,
        v_task.id
      )
      ON CONFLICT DO NOTHING;
    END IF;
  ELSIF NOT p_completed AND v_task.completed THEN
    UPDATE public.tasks
       SET completed = false,
           completed_at = NULL,
           updated_at = now()
     WHERE id = p_task_id
     RETURNING * INTO v_task;
  END IF;

  RETURN NEXT v_task;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_task(uuid, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_task(uuid, boolean)
  TO authenticated;
