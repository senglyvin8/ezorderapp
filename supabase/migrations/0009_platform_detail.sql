-- ============================================================================
--  EZ Order — more for the operator to go on
-- ============================================================================
--
--  The first version of platform_overview() answered "how big is each
--  merchant". That is the wrong first question. Running a service, what you
--  need to know is which merchants need something from you:
--
--    * signed up and never finished setting up — no menu, or no tables, so
--      they physically cannot take an order and probably do not know why
--    * set up and never took an order — onboarding worked, adoption did not
--    * were busy and have gone quiet — the shape of churn
--    * pressed against a plan limit — the shape of an upgrade
--
--  So this adds setup completeness, a recent-versus-previous week comparison,
--  and the contact details you would need to actually pick up the phone.
--
--  Still aggregates only: no order, no item, no customer note.
--
--  Run after 0008. Safe to re-run.
-- ============================================================================

-- The return type changes, and `create or replace` cannot alter one.
drop function if exists public.platform_overview();

create function public.platform_overview()
returns table (
  id             uuid,
  slug           text,
  name           text,
  logo           text,
  phone          text,
  address        text,
  plan           text,
  suspended      boolean,
  created_at     timestamptz,
  tables_used    integer,
  max_tables     integer,
  staff_used     integer,
  max_staff      integer,
  categories     integer,
  menu_items     integer,
  orders_total   integer,
  orders_today   integer,
  orders_7d      integer,
  orders_prev_7d integer,
  revenue_total  numeric,
  revenue_today  numeric,
  revenue_30d    numeric,
  last_order_at  timestamptz,
  owner_username text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;

  return query
  select
    r.id, r.slug, r.name, r.logo, r.phone, r.address,
    r.plan, r.suspended, r.created_at,

    (select count(*)::integer from public.restaurant_tables t
      where t.restaurant_id = r.id),
    l.max_tables,
    (select count(*)::integer from public.staff s
      where s.restaurant_id = r.id),
    l.max_staff,

    -- Setup completeness. A restaurant with no category, no dish or no table
    -- cannot take an order at all, however long ago they signed up.
    (select count(*)::integer from public.categories c
      where c.restaurant_id = r.id),
    (select count(*)::integer from public.menu_items m
      where m.restaurant_id = r.id),

    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id),
    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id
        and o.created_at >= date_trunc('day', now())),
    -- This week against the week before it: one number is a fact, two are a
    -- direction.
    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id
        and o.created_at >= now() - interval '7 days'),
    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id
        and o.created_at >= now() - interval '14 days'
        and o.created_at <  now() - interval '7 days'),

    -- Only money actually taken.
    (select coalesce(sum(o.total), 0) from public.orders o
      where o.restaurant_id = r.id and o.status in ('PAID','COMPLETED')),
    (select coalesce(sum(o.total), 0) from public.orders o
      where o.restaurant_id = r.id and o.status in ('PAID','COMPLETED')
        and o.created_at >= date_trunc('day', now())),
    (select coalesce(sum(o.total), 0) from public.orders o
      where o.restaurant_id = r.id and o.status in ('PAID','COMPLETED')
        and o.created_at >= now() - interval '30 days'),

    (select max(o.created_at) from public.orders o
      where o.restaurant_id = r.id),

    -- Who to address an email to. Not a contact address — the owner signs in
    -- with a username, and this app never asked them for a real one.
    (select s.username from public.staff s
      where s.restaurant_id = r.id and s.role = 'ADMIN' and s.username <> ''
      order by s.created_at limit 1)

  from public.restaurants r
  cross join lateral public.plan_limits(r.plan) l
  order by r.created_at;
end $$;

grant execute on function public.platform_overview() to authenticated;
