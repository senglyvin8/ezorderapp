-- ============================================================================
--  EZ Order — subscription plans
-- ============================================================================
--
--  FREE   $0      5 tables    2 staff   unlimited orders
--  BASIC  $5.99  20 tables    5 staff   unlimited orders
--  PRO    $9.99  unlimited   10 staff   unlimited orders
--
--  Orders are unlimited on every plan on purpose: charging a restaurant per
--  order would punish them for a good night.
--
--  The limits are enforced here, in triggers, rather than in the app. The app
--  keeps its own copy of the numbers so it can grey out a button and show
--  usage, but a patched client that ignores them still cannot get a sixth
--  table into a free restaurant.
--
--  Changing a restaurant's plan is a manual UPDATE for now — there is no
--  payment processing. See the bottom of this file.
--
--  Run after 0001–0005. Safe to re-run.
-- ============================================================================

alter table public.restaurants
  add column if not exists plan text not null default 'FREE';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'restaurants_plan_check'
  ) then
    alter table public.restaurants
      add constraint restaurants_plan_check
      check (plan in ('FREE','BASIC','PRO'));
  end if;
end $$;

comment on column public.restaurants.plan is
  'FREE, BASIC or PRO. Caps tables and staff via the triggers below. Changed '
  'by hand until billing exists; a client cannot write it (see the column '
  'grants in 0002_policies.sql).';

-- ------------------------------------------------------------------ limits

-- One place both triggers read, so the two can never drift apart.
create or replace function public.plan_limits(p_plan text)
returns table (max_tables integer, max_staff integer)
language sql immutable
set search_path = public, pg_temp
as $$
  -- Naming the columns, not `select *`: the values list carries three columns
  -- and this function returns two, so a star would hand back `plan` where
  -- max_tables belongs and fail with a return type mismatch.
  select t.max_tables, t.max_staff
    from (values
      ('FREE',   5,             2),
      ('BASIC',  20,            5),
      -- NULL is unlimited. Not a big number: a cap of 999 is one somebody
      -- eventually hits and cannot explain. Cast, so the column is typed
      -- integer rather than left unknown.
      ('PRO',    null::integer, 10)
    ) as t(plan, max_tables, max_staff)
   where t.plan = p_plan
$$;

grant execute on function public.plan_limits(text) to anon, authenticated;

-- --------------------------------------------------------------- the caps

create or replace function public.enforce_table_limit()
returns trigger language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_plan  text;
  v_limit integer;
  v_count integer;
begin
  select plan into v_plan from public.restaurants where id = new.restaurant_id;
  select max_tables into v_limit from public.plan_limits(v_plan);
  if v_limit is null then
    return new;
  end if;

  select count(*) into v_count
    from public.restaurant_tables
   where restaurant_id = new.restaurant_id;

  if v_count >= v_limit then
    raise exception
      'The % plan allows % tables. Upgrade to add more.', v_plan, v_limit
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

drop trigger if exists tables_plan_limit on public.restaurant_tables;
create trigger tables_plan_limit
  before insert on public.restaurant_tables
  for each row execute function public.enforce_table_limit();

create or replace function public.enforce_staff_limit()
returns trigger language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_plan  text;
  v_limit integer;
  v_count integer;
begin
  select plan into v_plan from public.restaurants where id = new.restaurant_id;
  select max_staff into v_limit from public.plan_limits(v_plan);
  if v_limit is null then
    return new;
  end if;

  -- Counts everyone with an account, including the owner and anyone switched
  -- off. A deactivated account still occupies a seat: it can be switched back
  -- on, and counting only active staff would make the cap trivially evadable.
  select count(*) into v_count
    from public.staff
   where restaurant_id = new.restaurant_id;

  if v_count >= v_limit then
    raise exception
      'The % plan allows % staff accounts. Upgrade to add more.', v_plan, v_limit
      using errcode = 'check_violation';
  end if;
  return new;
end $$;

drop trigger if exists staff_plan_limit on public.staff;
create trigger staff_plan_limit
  before insert on public.staff
  for each row execute function public.enforce_staff_limit();

-- ------------------------------------------------------------------ usage

-- What the admin screen shows. A function rather than a view so it can be
-- granted on its own, and so a caller only ever sees their own restaurant.
create or replace function public.plan_usage()
returns table (
  plan        text,
  tables_used integer,
  max_tables  integer,
  staff_used  integer,
  max_staff   integer
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    r.plan,
    (select count(*)::integer from public.restaurant_tables t
      where t.restaurant_id = r.id),
    l.max_tables,
    (select count(*)::integer from public.staff s
      where s.restaurant_id = r.id),
    l.max_staff
  from public.restaurants r
  cross join lateral public.plan_limits(r.plan) l
  where r.id = public.current_restaurant_id()
$$;

grant execute on function public.plan_usage() to authenticated;

-- ------------------------------------------------------- who may change it

-- The column grants in 0002 list exactly what a client may update, and `plan`
-- is not among them — so an admin cannot promote their own restaurant from
-- the settings screen. Re-stated here so the grant survives a re-run of that
-- file in either order.
revoke update on public.restaurants from anon, authenticated;
grant update (
  name, name_km, logo, phone, address,
  currency_symbol, currency_code, payment_methods
) on public.restaurants to authenticated;

-- ============================================================================
--  Changing a plan, until billing exists:
--
--      update public.restaurants set plan = 'BASIC' where slug = 'demo';
--
--  Downgrading does not delete anything. A restaurant that drops from PRO to
--  FREE with 30 tables keeps all 30 and simply cannot add a 31st — throwing
--  away a paying customer's data because their card expired would be a far
--  worse bug than a cap that is temporarily over.
-- ============================================================================
