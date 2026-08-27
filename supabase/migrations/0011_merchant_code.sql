-- ============================================================================
--  EZ Order — the merchant ID
-- ============================================================================
--
--  Every row that belongs to a restaurant already carries `restaurant_id`, and
--  which restaurant a member of staff belongs to has always been decided by
--  their row in `staff`. None of that changes. What was missing is an
--  identifier a *person* can use: something an owner can read down a phone to
--  their new cashier, and something support can ask for.
--
--  A uuid is not that. Neither is the slug, quite: the slug is in URLs and on
--  printed QR codes, it is chosen by whoever provisions the restaurant, and a
--  merchant who rebrands will one day want to change it. The merchant ID must
--  never change, because it is what staff type and what you quote back.
--
--  So: two identifiers doing two jobs.
--
--      id     uuid, internal, never shown
--      slug   URL-facing, vanity, changeable
--      code   EZ-4K7Q2M — human, spoken, permanent
--
--  The alphabet is Crockford base32: digits plus letters without I, L, O and
--  U. Nobody has to decide whether that was a one or an ell, and a code read
--  out over a bad line still arrives.
--
--  Run after 0001–0010. Safe to re-run.
-- ============================================================================

alter table public.restaurants add column if not exists code text;

-- ------------------------------------------------------------- reading one

-- Turns whatever somebody typed into the canonical form, or null if it cannot
-- be one. Spaces, lower case, a missing prefix, an O typed for a zero: all of
-- that is a person doing their best with a code read aloud, and all of it
-- should work.
--
-- Mirrored in `MerchantCode.normalize` in lib/models/merchant_code.dart —
-- change one and you must change the other.
create or replace function public.normalize_merchant_code(p_raw text)
returns text
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  if p_raw is null then
    return null;
  end if;

  v := upper(regexp_replace(p_raw, '[^0-9A-Za-z]', '', 'g'));

  -- The prefix is presentation. Drop it only when what is left is the right
  -- length, so a body that happens to start with EZ survives.
  if length(v) = 8 and left(v, 2) = 'EZ' then
    v := substr(v, 3);
  end if;

  if length(v) <> 6 then
    return null;
  end if;

  -- Crockford: I and L are ones, O is a zero. U is excluded from the alphabet
  -- rather than mapped, so a code can never spell anything unfortunate.
  v := translate(v, 'ILO', '110');

  if v !~ '^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{6}$' then
    return null;
  end if;

  return 'EZ-' || v;
end $$;

grant execute on function public.normalize_merchant_code(text) to anon, authenticated;

-- ------------------------------------------------------------- minting one

create or replace function public.new_merchant_code()
returns text
language plpgsql
volatile
set search_path = public, extensions, pg_temp
as $$
declare
  v_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  v_code     text;
  v_try      integer := 0;
begin
  loop
    v_code := 'EZ-';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * 32)::integer, 1);
    end loop;

    exit when not exists (
      select 1 from public.restaurants where code = v_code
    );

    -- 32^6 is a billion codes; colliding twenty times running means something
    -- is wrong with the random source, not with luck.
    v_try := v_try + 1;
    if v_try > 20 then
      raise exception 'Could not mint a unique merchant code';
    end if;
  end loop;

  return v_code;
end $$;

-- Backfill before the column is made mandatory. Existing merchants get a code
-- the first time this file runs and keep it forever after.
update public.restaurants set code = public.new_merchant_code()
 where code is null;

alter table public.restaurants alter column code set not null;

create unique index if not exists restaurants_code_key
  on public.restaurants (code);

comment on column public.restaurants.code is
  'The merchant ID, EZ-4K7Q2M. Immutable and unique. What staff type to bind '
  'a device and what support asks for. The slug is the URL-facing name and may '
  'change; this may not.';

-- New restaurants get one without provision_restaurant() having to know.
create or replace function public.assign_merchant_code()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.code is null or trim(new.code) = '' then
    new.code := public.new_merchant_code();
  end if;
  return new;
end $$;

drop trigger if exists restaurants_assign_code on public.restaurants;
create trigger restaurants_assign_code
  before insert on public.restaurants
  for each row execute function public.assign_merchant_code();

-- And nobody gets to change one afterwards. A merchant ID that can be edited
-- is a merchant ID that is wrong on somebody's printed card, in your support
-- notes, and on the tablet in their kitchen — all at once, and silently.
create or replace function public.freeze_merchant_code()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.code is distinct from old.code then
    raise exception 'A merchant ID cannot be changed once it is issued';
  end if;
  return new;
end $$;

drop trigger if exists restaurants_freeze_code on public.restaurants;
create trigger restaurants_freeze_code
  before update of code on public.restaurants
  for each row execute function public.freeze_merchant_code();

-- ------------------------------------------------------ resolving a code

-- What a device needs to bind itself to a merchant: enough to show the
-- restaurant's name and mark while somebody confirms they typed the right
-- thing, and the slug, which is what the sign-in machinery runs on.
--
-- Callable by anyone, and that is a deliberate, bounded amount of exposure.
-- It confirms whether one exact code exists — nothing more. There is no
-- listing, no prefix match and no search, so the only way to find a code is to
-- guess one of a billion, and a code on its own opens nothing: a PIN or a
-- password still stands between it and any data.
create or replace function public.restaurant_by_code(p_code text)
returns table (
  id   uuid,
  slug text,
  name text,
  logo text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select r.id, r.slug, r.name, r.logo
    from public.restaurants r
   where r.code = public.normalize_merchant_code(p_code)
$$;

grant execute on function public.restaurant_by_code(text) to anon, authenticated;

-- ------------------------------------------------- the console shows it too

-- The return type changes, and `create or replace` cannot alter one. The body
-- is 0009's with `code` added — the console's one query stays one query.
drop function if exists public.platform_overview();

create function public.platform_overview()
returns table (
  id             uuid,
  slug           text,
  code           text,
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
    r.id, r.slug, r.code, r.name, r.logo, r.phone, r.address,
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

-- ============================================================================
--  To read a merchant's ID by hand:
--
--    select code, name, slug from public.restaurants order by created_at;
-- ============================================================================
