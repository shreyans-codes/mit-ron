-- Run in Supabase SQL Editor (or psql).
-- Replaces public.friends with the one-row-per-pair schema (empty old table is fine).

DROP TABLE IF EXISTS public.friends CASCADE;
DROP TYPE IF EXISTS public.friendship_status CASCADE;

CREATE TYPE public.friendship_status AS ENUM ('pending', 'accepted', 'rejected');

CREATE TABLE public.friends (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  initiator_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  status public.friendship_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT friends_not_self CHECK (initiator_id <> recipient_id)
);

CREATE UNIQUE INDEX friends_one_per_pair ON public.friends (
  LEAST(initiator_id, recipient_id),
  GREATEST(initiator_id, recipient_id)
);

CREATE INDEX friends_initiator_status ON public.friends (initiator_id, status);
CREATE INDEX friends_recipient_status ON public.friends (recipient_id, status);
