-- ============================================================================
--  EZ Order — the platform operator's console
-- ============================================================================
--
--  A second, separate audience: you, running the service, rather than a
--  restaurant running its floor. Platform admins are not staff of any
--  restaurant, so they get their own table rather than a flag on `staff`.
--
--  Everything the console does goes through the SECURITY DEFINER functions
--  below. It never selects a merchant's tables directly, and none of these
--  functions returns an individual order, item or customer note — only counts
--  and totals. That is a deliberate limit: you can bill and support a merchant
--  without being able to read what a particular diner ate, and it is a far
--  easier answer to give when a merchant asks what you can see.
--
--  Run after 0001–0007. Safe to re-run.
-- ============================================================================

-- --------------------------------------------------------- who runs the show

create table if not exists public.platform_admins (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null default '',
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;

-- No policy at all: nothing reads this table from a client. The only thing
-- that consults it is is_platform_admin(), which is SECURITY DEFINER and so
-- bypasses RLS. A restaurant admin cannot read the list, and — more to the
-- point — cannot add themselves to it.
--
-- Membership is granted by hand, in the SQL editor. See the bottom of the file.

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  -- coalesce, because `exists` on no rows for an unauthenticated caller must
  -- be false rather than null. The same NULL-versus-false mistake in the
  -- restaurant guards let an anonymous caller walk past a permission check.
  select coalesce(
    (select true from public.platform_admins where id = auth.uid()), false)
$$;

grant execute on function public.is_platform_admin() to anon, authenticated;

-- ------------------------------------------------------------- suspension

alter table public.restaurants
  add column if not exists suspended boolean not null default false;

comment on column public.restaurants.suspended is
  'Set by the platform console. Stops new orders; staff can still sign in and '
  'read their history, because freezing a restaurant should not also delete '
  'their access to yesterday''s takings.';

-- The ordering path is the thing that stops. Staff keep their access on
-- purpose: a merchant who has fallen behind on payment still needs to close
-- out the orders already on their floor, and locking them out of their own
-- history would be punitive rather than persuasive.
create or replace function public.assert_not_suspended(p_restaurant_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.restaurants
     where id = p_restaurant_id and suspended
  ) then
    raise exception
      'This restaurant is not accepting orders at the moment.'
      using errcode = 'check_violation';
  end if;
end $$;

grant execute on function public.assert_not_suspended(uuid) to anon, authenticated;

-- ------------------------------------------------------------- the console

-- One row per merchant: what they are on, what they are using, what they have
-- taken. Counts and totals only.
create or replace function public.platform_overview()
returns table (
  id            uuid,
  slug          text,
  name          text,
  plan          text,
  suspended     boolean,
  created_at    timestamptz,
  tables_used   integer,
  max_tables    integer,
  staff_used    integer,
  max_staff     integer,
  orders_total  integer,
  orders_today  integer,
  revenue_total numeric,
  revenue_today numeric,
  last_order_at timestamptz
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
    r.id, r.slug, r.name, r.plan, r.suspended, r.created_at,
    (select count(*)::integer from public.restaurant_tables t
      where t.restaurant_id = r.id),
    l.max_tables,
    (select count(*)::integer from public.staff s
      where s.restaurant_id = r.id),
    l.max_staff,
    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id),
    (select count(*)::integer from public.orders o
      where o.restaurant_id = r.id
        and o.created_at >= date_trunc('day', now())),
    -- Only money actually taken. An order on the stove has earned nothing yet,
    -- and a cancelled one never will.
    (select coalesce(sum(o.total), 0) from public.orders o
      where o.restaurant_id = r.id and o.status in ('PAID','COMPLETED')),
    (select coalesce(sum(o.total), 0) from public.orders o
      where o.restaurant_id = r.id and o.status in ('PAID','COMPLETED')
        and o.created_at >= date_trunc('day', now())),
    (select max(o.created_at) from public.orders o
      where o.restaurant_id = r.id)
  from public.restaurants r
  cross join lateral public.plan_limits(r.plan) l
  order by r.created_at;
end $$;

grant execute on function public.platform_overview() to authenticated;

-- Signing up a customer, without anybody pasting SQL.
create or replace function public.platform_create_merchant(
  p_slug           text,
  p_name           text,
  p_admin_username text,
  p_admin_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;
  return public.provision_restaurant(
    p_slug, p_name, p_admin_username, p_admin_password);
end $$;

grant execute on function
  public.platform_create_merchant(text, text, text, text) to authenticated;

create or replace function public.platform_set_plan(
  p_restaurant_id uuid,
  p_plan          text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;
  if p_plan not in ('FREE','BASIC','PRO') then
    raise exception 'Unknown plan %', p_plan;
  end if;

  -- Downgrading deletes nothing. A merchant dropping to FREE with thirty
  -- tables keeps all thirty and simply cannot add a thirty-first.
  update public.restaurants set plan = p_plan where id = p_restaurant_id;
  if not found then
    raise exception 'Unknown restaurant';
  end if;
end $$;

create or replace function public.platform_set_suspended(
  p_restaurant_id uuid,
  p_suspended     boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;
  update public.restaurants set suspended = p_suspended
   where id = p_restaurant_id;
  if not found then
    raise exception 'Unknown restaurant';
  end if;
end $$;

grant execute on function public.platform_set_plan(uuid, text) to authenticated;
grant execute on function
  public.platform_set_suspended(uuid, boolean) to authenticated;

-- ------------------------------------------- suspension bites where it counts

-- place_order is redefined here rather than in 0003 so the suspension check
-- lives beside the thing that introduced it. Identical to 0003 apart from the
-- one guard at the top: a flag nothing consults is decoration.
create or replace function public.place_order(
  p_restaurant_id uuid,
  p_type          text,
  p_table_id      uuid,
  p_note          text,
  p_items         jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order_id     uuid;
  v_number       integer;
  v_table_number text;
  v_subtotal     numeric(10,2) := 0;
  v_placed_by    text;
  v_item         jsonb;
  v_price        numeric(10,2);
  v_available    boolean;
  v_name         text;
  v_name_km      text;
  v_quantity     integer;
begin
  perform public.assert_not_suspended(p_restaurant_id);

  if p_type not in ('DINE_IN','TAKEAWAY') then
    raise exception 'An order is either DINE_IN or TAKEAWAY';
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'The cart is empty';
  end if;

  if p_type = 'DINE_IN' then
    select number into v_table_number
      from public.restaurant_tables
     where id = p_table_id and restaurant_id = p_restaurant_id;
    if v_table_number is null then
      raise exception 'No table selected — scan a table QR first';
    end if;
  else
    p_table_id := null;
  end if;

  if public.current_restaurant_id() = p_restaurant_id then
    if not public.can_take_payment() then
      raise exception 'You are not allowed to take an order for a customer';
    end if;
    select name into v_placed_by from public.staff where id = auth.uid();
  end if;

  v_number := public.next_order_number(p_restaurant_id);

  insert into public.orders (
    restaurant_id, order_number, type, table_id, table_number,
    status, customer_note, placed_by, customer_id
  ) values (
    p_restaurant_id, v_number, p_type, p_table_id, v_table_number,
    'NEW', nullif(trim(coalesce(p_note,'')), ''), v_placed_by,
    case when v_placed_by is null then auth.uid() end
  )
  returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_quantity := greatest(1, coalesce((v_item->>'quantity')::integer, 1));

    select
        case when discount_percent > 0
             then round(price * (100 - discount_percent) / 100.0, 2)
             else price end,
        available, name, name_km
      into v_price, v_available, v_name, v_name_km
      from public.menu_items
     where id = (v_item->>'food_id')::uuid
       and restaurant_id = p_restaurant_id;

    if v_price is null then
      raise exception 'That dish is not on this menu';
    end if;
    if not v_available then
      raise exception '% is sold out', v_name;
    end if;

    insert into public.order_items
      (order_id, food_id, name, name_km, price, quantity, note)
    values
      (v_order_id, (v_item->>'food_id')::uuid, v_name, v_name_km,
       v_price, v_quantity, nullif(trim(coalesce(v_item->>'note','')), ''));

    v_subtotal := v_subtotal + v_price * v_quantity;
  end loop;

  update public.orders
     set subtotal = v_subtotal, total = v_subtotal
   where id = v_order_id;

  return v_order_id;
end $$;

grant execute on function
  public.place_order(uuid, text, uuid, text, jsonb) to anon, authenticated;

-- ============================================================================
--  Making yourself a platform administrator
--
--  1. Create the account. Authentication → Users → Add user, with a real email
--     and password, and tick "Auto Confirm User".
--
--  2. Then, here:
--
--         insert into public.platform_admins (id, name)
--         select id, 'Your Name' from auth.users where email = 'you@example.com'
--         on conflict (id) do nothing;
--
--  There is deliberately no way to do this from any app. The table has RLS on
--  and no policy, so the only route in is the SQL editor — which means an
--  attacker needs your database credentials, not merely an account.
-- ============================================================================
