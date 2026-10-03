CREATE TABLE IF NOT EXISTS public.push_device_tokens (
  token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS push_device_tokens_user_id_idx
  ON public.push_device_tokens(user_id);

ALTER TABLE public.push_device_tokens ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.push_notification_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scheduled_for timestamptz NOT NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  processing_started_at timestamptz NULL,
  dispatched_at timestamptz NULL,
  last_error text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (task_id, scheduled_for)
);

CREATE INDEX IF NOT EXISTS push_notification_jobs_due_idx
  ON public.push_notification_jobs(scheduled_for)
  WHERE status = 'pending';

ALTER TABLE public.push_notification_jobs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.sync_task_push_reminder()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    UPDATE public.push_notification_jobs
    SET status = 'cancelled'
    WHERE task_id = NEW.id AND status = 'pending';
  END IF;

  IF NEW.reminder_at IS NOT NULL
     AND NEW.completed = FALSE
     AND NEW.reminder_at > now() THEN
    INSERT INTO public.push_notification_jobs (
      task_id,
      user_id,
      scheduled_for,
      title
    )
    VALUES (
      NEW.id,
      NEW.user_id,
      NEW.reminder_at,
      NEW.title
    )
    ON CONFLICT (task_id, scheduled_for) DO UPDATE
      SET title = EXCLUDED.title,
          status = 'pending',
          dispatched_at = NULL,
          last_error = NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_push_reminder ON public.tasks;
CREATE TRIGGER tasks_push_reminder
  AFTER INSERT OR UPDATE OF reminder_at, title, completed
  ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_task_push_reminder();

CREATE OR REPLACE FUNCTION public.claim_due_push_notification_jobs(
  batch_size integer DEFAULT 100
)
RETURNS SETOF public.push_notification_jobs
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH due_jobs AS (
    SELECT id
    FROM public.push_notification_jobs
    WHERE scheduled_for <= now()
      AND (
        status = 'pending'
        OR (
          status = 'processing'
          AND processing_started_at < now() - interval '5 minutes'
        )
      )
    ORDER BY scheduled_for
    FOR UPDATE SKIP LOCKED
    LIMIT LEAST(GREATEST(COALESCE(batch_size, 100), 1), 100)
  )
  UPDATE public.push_notification_jobs AS jobs
  SET status = 'processing',
      processing_started_at = now()
  FROM due_jobs
  WHERE jobs.id = due_jobs.id
  RETURNING jobs.*;
$$;

REVOKE ALL ON FUNCTION public.claim_due_push_notification_jobs(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_push_notification_jobs(integer)
  TO service_role;
