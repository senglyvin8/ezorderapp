-- ============================================================================
--  EZ Order — row level security
-- ============================================================================
--
--  The shape of it:
--
--    * Menus, tables and restaurant profiles are world-readable. A diner scans
--      a sticker and must be able to read the menu before they are anyone.
--    * Orders are readable by the staff of that restaurant, and by the diner
--      who placed them. Nobody else.
--    * Nothing is written directly. Every mutation goes through a SECURITY
--      DEFINER function in 0003_rpc.sql that checks the caller's role and the
--      order's state first. That is why you will find no INSERT or UPDATE
--      policy on `orders` below — the absence is deliberate, not an oversight.
--
--  Doing it this way means the state machine (Rule 6, Rule 7, cancel-only-
--  while-queued) is enforced in one place in the database, instead of being
--  reconstructed out of CHECK constraints and per-column policies.
-- ============================================================================

alter table public.restaurants       enable row level security;
alter table public.staff             enable row level security;
alter table public.categories        enable row level security;
alter table public.menu_items        enable row level security;
alter table public.restaurant_tables enable row level security;
alter table public.orders            enable row level security;
alter table public.order_items       enable row level security;

-- ----------------------------------------------------------------- helpers

-- Which restaurant the caller works for, or null if they are a diner.
--
-- SECURITY DEFINER so it can read `staff` without tripping the policies on
-- `staff`, which would otherwise recurse: the policy needs the function and
-- the function needs the table. `search_path` is pinned so the function cannot
-- be redirected at a shadowed table.
create or replace function public.current_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select restaurant_id from public.staff
  where id = auth.uid() and active
$$;

create or replace function public.current_staff_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role from public.staff
  where id = auth.uid() and active
$$;

-- Admin is a superset: in a small shop the owner works the kitchen and the
-- till as well. Mirrors StaffRole in lib/models/staff_account.dart.
--
-- Every one of these coalesces to false, and that is load-bearing. For a caller
-- who is not staff at all, current_staff_role() is NULL, and `NULL = 'ADMIN'`
-- is NULL rather than false. The guards read `if not can_manage_restaurant()
-- then raise`, and `if NULL then` does not take the branch — so without the
-- coalesce an anonymous caller walks straight past the permission check and is
-- stopped only by whatever constraint happens to catch them further down.
create or replace function public.can_manage_restaurant()
returns boolean language sql stable
set search_path = public, pg_temp
as $$ select coalesce(public.current_staff_role() = 'ADMIN', false) $$;

create or replace function public.can_work_kitchen()
returns boolean language sql stable
set search_path = public, pg_temp
as $$ select coalesce(public.current_staff_role() in ('ADMIN','KITCHEN'), false) $$;

create or replace function public.can_take_payment()
returns boolean language sql stable
set search_path = public, pg_temp
as $$ select coalesce(public.current_staff_role() in ('ADMIN','CASHIER'), false) $$;

grant execute on function public.current_restaurant_id() to anon, authenticated;
grant execute on function public.current_staff_role()   to anon, authenticated;
grant execute on function public.can_manage_restaurant() to anon, authenticated;
grant execute on function public.can_work_kitchen()      to anon, authenticated;
grant execute on function public.can_take_payment()      to anon, authenticated;

-- ------------------------------------------------------------- restaurants

-- Public: a diner needs the name, logo, currency and payment methods to read
-- a menu and a receipt. None of that is a secret.
drop policy if exists restaurants_read on public.restaurants;
create policy restaurants_read on public.restaurants
  for select using (true);

-- Only an admin, and only their own restaurant. `next_order_number` is
-- protected separately by a trigger below.
drop policy if exists restaurants_admin_update on public.restaurants;
create policy restaurants_admin_update on public.restaurants
  for update
  using  (id = public.current_restaurant_id() and public.can_manage_restaurant())
  with check (id = public.current_restaurant_id() and public.can_manage_restaurant());

-- An admin editing settings must not be able to rewind the order counter and
-- collide with numbers already issued.
create or replace function public.protect_order_counter()
returns trigger language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.next_order_number <> old.next_order_number then
    new.next_order_number := old.next_order_number;
  end if;
  if new.slug <> old.slug then
    raise exception 'A restaurant slug cannot be changed once QR codes are printed';
  end if;
  return new;
end $$;

drop trigger if exists restaurants_protect_counter on public.restaurants;
create trigger restaurants_protect_counter
  before update on public.restaurants
  for each row execute function public.protect_order_counter();

-- ------------------------------------------------------------------- staff

-- Staff may see their colleagues; the PIN pad lists kitchen and cashier names
-- to tap. No secrets live here — passwords are Supabase Auth's problem.
drop policy if exists staff_read on public.staff;
create policy staff_read on public.staff
  for select using (restaurant_id = public.current_restaurant_id());

-- Creating and deleting staff also creates and deletes auth users, so it runs
-- through RPCs rather than direct writes. Admins may rename and deactivate.
drop policy if exists staff_admin_update on public.staff;
create policy staff_admin_update on public.staff
  for update
  using  (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant())
  with check (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant()
          -- Moving someone to another restaurant, or promoting them to admin
          -- by hand, is not an edit — it is a different account.
          and role = (select role from public.staff s where s.id = staff.id));

-- --------------------------------------------------- menu, categories, tables

-- Public read: this is the menu a diner scans for.
drop policy if exists categories_read on public.categories;
create policy categories_read on public.categories for select using (true);

drop policy if exists menu_items_read on public.menu_items;
create policy menu_items_read on public.menu_items for select using (true);

drop policy if exists tables_read on public.restaurant_tables;
create policy tables_read on public.restaurant_tables for select using (true);

-- Admin-only writes, scoped to their own restaurant. `with check` on insert
-- and update is what stops a client planting a row in another restaurant.
drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write on public.categories
  for all
  using  (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant())
  with check (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant());

drop policy if exists menu_items_admin_write on public.menu_items;
create policy menu_items_admin_write on public.menu_items
  for all
  using  (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant())
  with check (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant());

drop policy if exists tables_admin_write on public.restaurant_tables;
create policy tables_admin_write on public.restaurant_tables
  for all
  using  (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant())
  with check (restaurant_id = public.current_restaurant_id()
          and public.can_manage_restaurant());

-- ------------------------------------------------------------------ orders

-- Staff see every order in their own restaurant. A diner sees the orders they
-- placed, and nothing else — not the table's, not the restaurant's.
--
-- Deliberately no INSERT, UPDATE or DELETE policy: every write goes through
-- the functions in 0003_rpc.sql, which check role and state first.
drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders
  for select using (
    restaurant_id = public.current_restaurant_id()
    or (customer_id is not null and customer_id = auth.uid())
  );

drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items
  for select using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
        and (
          o.restaurant_id = public.current_restaurant_id()
          or (o.customer_id is not null and o.customer_id = auth.uid())
        )
    )
  );
