-- CaliMind Supabase Schema
-- Run this in your Supabase SQL editor to bootstrap the database

-- ============================================================
-- TASKS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.tasks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title            text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
  description      text NULL CHECK (description IS NULL OR char_length(description) <= 1000),
  category         text NOT NULL DEFAULT 'Personal'
                        CHECK (category IN ('Class Rep', 'Club President', 'Study', 'Personal')),
  duration         int NOT NULL DEFAULT 30 CHECK (duration BETWEEN 5 AND 480),
  deadline         timestamptz NULL,
  preferred_time   text NULL CHECK (preferred_time IN ('Morning', 'Afternoon', 'Evening', 'Night')),
  specific_time    text NULL CHECK (specific_time IS NULL OR specific_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  priority         smallint NOT NULL DEFAULT 2 CHECK (priority IN (1, 2, 3)),
  completed        boolean NOT NULL DEFAULT false,
  completed_at     timestamptz NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Auto-update timestamps and completed_at
CREATE OR REPLACE FUNCTION public.handle_task_timestamps()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.completed = TRUE AND OLD.completed = FALSE THEN
    NEW.completed_at := now();
  ELSIF NEW.completed = FALSE AND OLD.completed = TRUE THEN
    NEW.completed_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_timestamps ON public.tasks;
CREATE TRIGGER tasks_timestamps
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.handle_task_timestamps();

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tasks_user_only" ON public.tasks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- SCHEDULE_BLOCKS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.schedule_blocks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_id        uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  schedule_date  date NOT NULL,
  start_time     time NOT NULL,
  end_time       time NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Enable GiST for tsrange exclusion constraint (requires btree_gist extension)
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE public.schedule_blocks
  ADD CONSTRAINT schedule_blocks_no_overlap
  EXCLUDE USING gist (
    user_id WITH =,
    tsrange(schedule_date + start_time, schedule_date + end_time, '[)') WITH &&
  );

ALTER TABLE public.schedule_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "schedule_user_only" ON public.schedule_blocks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- PROFILES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  user_id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data_retention_days    int NOT NULL DEFAULT 90 CHECK (data_retention_days BETWEEN 1 AND 3650),
  allow_email_processing boolean NOT NULL DEFAULT true,
  marketing_opt_in       boolean NOT NULL DEFAULT false,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_user_only" ON public.profiles
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- AUDIT_LOGS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type          text NOT NULL,
  ip_address_redacted  text NULL,
  metadata             jsonb NULL,
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit_user_read_only" ON public.audit_logs
  FOR SELECT USING (auth.uid() = user_id);
-- Inserts handled server-side only (no client write RLS)

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS tasks_user_id_idx ON public.tasks(user_id);
CREATE INDEX IF NOT EXISTS tasks_category_idx ON public.tasks(category);
CREATE INDEX IF NOT EXISTS tasks_completed_idx ON public.tasks(completed);
CREATE INDEX IF NOT EXISTS schedule_blocks_date_idx ON public.schedule_blocks(user_id, schedule_date);
CREATE INDEX IF NOT EXISTS audit_logs_user_idx ON public.audit_logs(user_id, created_at DESC);
