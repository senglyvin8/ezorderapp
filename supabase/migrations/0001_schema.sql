-- ============================================================================
--  EZ Order — schema
-- ============================================================================
--
--  Multi-tenant: one Supabase project serves many restaurants, and every row
--  that belongs to a restaurant carries `restaurant_id`. Which restaurant a
--  member of staff belongs to is decided by their row in `staff`, never by
--  anything the client sends, so a tampered client cannot reach across into
--  someone else's orders.
--
--  Run order: 0001_schema.sql, then 0002_policies.sql, then 0003_rpc.sql.
--  0004_seed.sql is optional and creates a demo restaurant to look at.
--
--  Menus are readable by anyone: a diner scans a QR code and has to be able to
--  read the menu before they are anyone at all. Orders are not — see
--  0002_policies.sql.
-- ============================================================================

-- Supabase ships pgcrypto in the `extensions` schema and this is normally a
-- no-op. It is spelled out so a bare Postgres puts crypt() and gen_salt()
-- where the account functions in 0004 expect to find them.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- restaurants

create table if not exists public.restaurants (
  id                uuid primary key default gen_random_uuid(),
  -- Appears in the QR link, so it has to be URL-safe and stable.
  slug              text not null unique
                      check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  name              text not null check (length(trim(name)) > 0),
  name_km           text not null default '',
  logo              text not null default '🍽️',
  phone             text not null default '',
  address           text not null default '',
  currency_symbol   text not null default '$',
  currency_code     text not null default 'USD',
  -- Rule 10: what the cashier may accept. First entry is the default.
  payment_methods   text[] not null default array['Cash','KHQR','Card','Other'],
  -- Rule 12: order numbers are unique per restaurant. Handed out by
  -- next_order_number() under a row lock, never by the client.
  next_order_number integer not null default 101,
  created_at        timestamptz not null default now()
);

comment on column public.restaurants.next_order_number is
  'Next order number to hand out. Incremented under a row lock by '
  'next_order_number(); never written by a client.';

-- --------------------------------------------------------------------- staff

-- One row per person who can sign in. The primary key IS the auth user id, so
-- `auth.uid()` is enough to find someone's restaurant and role in one lookup.
create table if not exists public.staff (
  id            uuid primary key references auth.users(id) on delete cascade,
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name          text not null check (length(trim(name)) > 0),
  role          text not null check (role in ('ADMIN','KITCHEN','CASHIER')),
  -- Admins sign in by username; kitchen and cashier tap their name and enter a
  -- PIN, so they have none. Unique per restaurant, not globally: two
  -- restaurants may each have an "admin".
  username      text not null default '',
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

create unique index if not exists staff_username_per_restaurant
  on public.staff (restaurant_id, lower(username))
  where username <> '';

create index if not exists staff_restaurant_idx on public.staff (restaurant_id);

-- ---------------------------------------------------------------- categories

create table if not exists public.categories (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name          text not null check (length(trim(name)) > 0),
  name_km       text not null default '',
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists categories_restaurant_idx
  on public.categories (restaurant_id, sort_order);

-- ---------------------------------------------------------------- menu items

create table if not exists public.menu_items (
  id               uuid primary key default gen_random_uuid(),
  restaurant_id    uuid not null references public.restaurants(id) on delete cascade,
  -- Deleting a category takes its dishes with it, matching the admin UI, which
  -- warns how many dishes will go.
  category_id      uuid not null references public.categories(id) on delete cascade,
  name             text not null check (length(trim(name)) > 0),
  name_km          text not null default '',
  description      text not null default '',
  description_km   text not null default '',
  price            numeric(10,2) not null check (price >= 0),
  discount_percent integer not null default 0
                     check (discount_percent between 0 and 90),
  image            text not null default 'plate',
  -- Base64 of a photo the admin uploaded, capped in the client at ~700KB.
  photo            text,
  available        boolean not null default true,
  popular          boolean not null default false,
  signature        boolean not null default false,
  created_at       timestamptz not null default now()
);

create index if not exists menu_items_restaurant_idx
  on public.menu_items (restaurant_id);
create index if not exists menu_items_category_idx
  on public.menu_items (category_id);

-- --------------------------------------------------------------------- tables

create table if not exists public.restaurant_tables (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  number        text not null check (length(trim(number)) > 0),
  name          text not null default '',
  -- Rule 2: what the printed QR code encodes. Unique across the project so a
  -- scan resolves to exactly one table without knowing the restaurant first.
  qr_id         text not null unique,
  created_at    timestamptz not null default now(),
  unique (restaurant_id, number)
);

create index if not exists tables_restaurant_idx
  on public.restaurant_tables (restaurant_id);

-- --------------------------------------------------------------------- orders

create table if not exists public.orders (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants(id) on delete cascade,
  order_number   integer not null,
  type           text not null default 'DINE_IN'
                   check (type in ('DINE_IN','TAKEAWAY')),
  -- Rule 11 as amended: a dine-in order carries its table, a takeaway order
  -- carries none and is called by its number.
  table_id       uuid references public.restaurant_tables(id) on delete set null,
  -- Snapshot, so a renamed or deleted table does not rewrite history.
  table_number   text,
  status         text not null default 'NEW'
                   check (status in
                     ('NEW','COOKING','READY','PAID','COMPLETED','CANCELLED')),
  subtotal       numeric(10,2) not null default 0 check (subtotal >= 0),
  total          numeric(10,2) not null default 0 check (total >= 0),
  customer_note  text,
  payment_method text,
  -- Name of the staff member who keyed it in at the counter; null when the
  -- customer placed it from their own phone.
  placed_by      text,
  cancelled_by   text,
  -- The anonymous auth user who placed it, so RLS can scope "my orders"
  -- without a diner needing an account.
  customer_id    uuid,
  created_at     timestamptz not null default now(),
  paid_at        timestamptz,
  cancelled_at   timestamptz,
  unique (restaurant_id, order_number),
  -- Rule 11, enforced by the database rather than only by the client.
  constraint dine_in_needs_a_table
    check (type <> 'DINE_IN' or table_number is not null)
);

create index if not exists orders_restaurant_status_idx
  on public.orders (restaurant_id, status, created_at);
create index if not exists orders_customer_idx
  on public.orders (customer_id) where customer_id is not null;

-- ---------------------------------------------------------------- order items

create table if not exists public.order_items (
  id       uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  -- Not a foreign key on purpose: a dish removed from the menu next week must
  -- not erase what somebody ate today. Name and price are snapshots too.
  food_id  uuid,
  name     text not null,
  name_km  text not null default '',
  price    numeric(10,2) not null check (price >= 0),
  quantity integer not null check (quantity > 0),
  note     text
);

create index if not exists order_items_order_idx on public.order_items (order_id);

-- ------------------------------------------------------------------ realtime

-- What the kitchen board, the till and the customer's tracker listen to. This
-- is what makes the live sync real across devices rather than a trick that
-- only worked because everything was on one phone.
alter table public.orders replica identity full;
alter table public.order_items replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'order_items'
  ) then
    alter publication supabase_realtime add table public.order_items;
  end if;
end $$;
