-- ============================================================================
--  EZ Order — one place_order, not two
-- ============================================================================
--
--  0013 added p_client_key and left the five-argument form behind, reasoning
--  that a client built before the migration should keep working. That was
--  exactly backwards, and it took ordering down.
--
--  PostgREST resolves a function by the argument names it is given. With both
--  forms present and the sixth argument carrying a default, a call with the
--  original five names matches *both* — and PostgREST refuses to guess:
--
--      PGRST203  Could not choose the best candidate function between:
--                public.place_order(...jsonb), public.place_order(...text)
--
--  Which is every order from every client built before 0013. The overload kept
--  for compatibility is the thing that broke compatibility.
--
--  Dropping it leaves one candidate. A five-argument call then resolves
--  against it and p_client_key takes its default of null — which is precisely
--  the old behaviour, with no duplicate protection and no ambiguity.
--
--  Run after 0013. Safe to re-run.
-- ============================================================================

drop function if exists public.place_order(uuid, text, uuid, text, jsonb);

-- Belt and braces: confirm exactly one remains, so a half-applied schema says
-- so here rather than at the first order of the evening.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'place_order';

  if v_count <> 1 then
    raise exception 'Expected exactly one place_order, found %', v_count;
  end if;
end $$;
