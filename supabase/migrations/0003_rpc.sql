-- ============================================================================
--  EZ Order — the mutations
-- ============================================================================
--
--  Every write to an order goes through one of these. They are SECURITY
--  DEFINER, so they can write tables that have no INSERT/UPDATE policy at all,
--  and each one checks the caller's role and the order's current state before
--  it does. That puts the rules the app is built on in exactly one place:
--
--    Rule 6   kitchen owns NEW -> COOKING -> READY
--    Rule 7   cashier owns READY -> PAID -> COMPLETED
--    Rule 12  order numbers are unique per restaurant
--             an order may only be edited or cancelled while still queued
--
--  The client mirrors these checks so it can grey out a button, but the client
--  is not what enforces them.
-- ============================================================================

-- ------------------------------------------------------------ order numbers

-- Rule 12. The UPDATE takes a row lock, so two tills submitting at the same
-- instant get different numbers rather than a duplicate-key error.
create or replace function public.next_order_number(p_restaurant_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_number integer;
begin
  update public.restaurants
     set next_order_number = next_order_number + 1
   where id = p_restaurant_id
   returning next_order_number - 1 into v_number;

  if v_number is null then
    raise exception 'Unknown restaurant';
  end if;
  return v_number;
end $$;

revoke execute on function public.next_order_number(uuid) from anon, authenticated;

-- ------------------------------------------------------------- place_order

-- Used by a diner on their own phone and by a cashier at the counter. The
-- difference is p_placed_by: null when the customer placed it themselves.
--
-- p_items is a JSON array of {food_id, name, name_km, price, quantity, note}.
-- Prices are taken from the menu here, not from the client, so a tampered
-- client cannot order a $12 dish for 1 cent.
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
  if p_type not in ('DINE_IN','TAKEAWAY') then
    raise exception 'An order is either DINE_IN or TAKEAWAY';
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'The cart is empty';
  end if;

  -- Rule 11: a dine-in order carries its table; takeaway carries none.
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

  -- A member of staff placing this is taking it at the counter. Anyone else
  -- is the customer, and their order is tagged with their anonymous uid so
  -- they can watch it without an account.
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

    -- Rule 9, and the price, both read from the menu rather than trusted.
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

-- ------------------------------------------------------- status transitions

-- Shared by all four transitions: find the order, check it belongs to the
-- caller's restaurant, and check it is where it is expected to be.
create or replace function public.assert_transition(
  p_order_id uuid,
  p_from     text
)
returns public.orders
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Unknown order';
  end if;
  if v_order.restaurant_id is distinct from public.current_restaurant_id() then
    raise exception 'That order belongs to another restaurant';
  end if;
  if v_order.status <> p_from then
    raise exception 'Order #% is %, it cannot move from %',
      v_order.order_number, v_order.status, p_from;
  end if;
  return v_order;
end $$;

revoke execute on function public.assert_transition(uuid, text) from anon, authenticated;

-- Rule 6 — kitchen owns NEW -> COOKING -> READY.
create or replace function public.start_cooking(p_order_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not public.can_work_kitchen() then
    raise exception 'You are not allowed to work the kitchen';
  end if;
  perform public.assert_transition(p_order_id, 'NEW');
  update public.orders set status = 'COOKING' where id = p_order_id;
end $$;

create or replace function public.mark_ready(p_order_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not public.can_work_kitchen() then
    raise exception 'You are not allowed to work the kitchen';
  end if;
  perform public.assert_transition(p_order_id, 'COOKING');
  update public.orders set status = 'READY' where id = p_order_id;
end $$;

-- Rule 7 — cashier owns READY -> PAID -> COMPLETED.
create or replace function public.collect_payment(
  p_order_id uuid,
  p_method   text
)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
begin
  if not public.can_take_payment() then
    raise exception 'You are not allowed to take payment';
  end if;
  v_order := public.assert_transition(p_order_id, 'READY');

  -- Rule 10: only a method this restaurant actually accepts.
  if not exists (
    select 1 from public.restaurants
     where id = v_order.restaurant_id and p_method = any(payment_methods)
  ) then
    raise exception '% is not a payment method this restaurant accepts', p_method;
  end if;

  update public.orders
     set status = 'PAID', payment_method = p_method, paid_at = now()
   where id = p_order_id;
end $$;

create or replace function public.complete_order(p_order_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not public.can_take_payment() then
    raise exception 'You are not allowed to close an order';
  end if;
  perform public.assert_transition(p_order_id, 'PAID');
  update public.orders set status = 'COMPLETED' where id = p_order_id;
end $$;

-- Only while it is still queued: once a pan is on the heat the dish exists
-- whether or not it is still wanted.
create or replace function public.cancel_order(p_order_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
  v_name  text;
begin
  if not public.can_take_payment() then
    raise exception 'You are not allowed to cancel an order';
  end if;
  v_order := public.assert_transition(p_order_id, 'NEW');
  select name into v_name from public.staff where id = auth.uid();

  update public.orders
     set status = 'CANCELLED', cancelled_by = v_name, cancelled_at = now()
   where id = p_order_id;
end $$;

grant execute on function public.start_cooking(uuid)          to authenticated;
grant execute on function public.mark_ready(uuid)             to authenticated;
grant execute on function public.collect_payment(uuid, text)  to authenticated;
grant execute on function public.complete_order(uuid)         to authenticated;
grant execute on function public.cancel_order(uuid)           to authenticated;

-- --------------------------------------------------------- editing an order

-- A quantity of zero drops the line. Removing the last one is refused: an
-- order with nothing on it is not something the kitchen or the till can act
-- on, so that case is a cancellation and has to be made as one.
create or replace function public.set_order_item_quantity(
  p_order_id uuid,
  p_item_id  uuid,
  p_quantity integer
)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders;
  v_count integer;
begin
  if not public.can_take_payment() then
    raise exception 'You are not allowed to change an order';
  end if;
  v_order := public.assert_transition(p_order_id, 'NEW');

  if not exists (
    select 1 from public.order_items
     where id = p_item_id and order_id = p_order_id
  ) then
    raise exception 'That dish is not on this order';
  end if;

  select count(*) into v_count from public.order_items where order_id = p_order_id;

  if p_quantity <= 0 then
    if v_count <= 1 then
      raise exception
        'That is the only dish left — cancel order #% instead',
        v_order.order_number;
    end if;
    delete from public.order_items where id = p_item_id;
  else
    update public.order_items set quantity = p_quantity where id = p_item_id;
  end if;

  update public.orders o
     set subtotal = c.sum, total = c.sum
    from (
      select coalesce(sum(price * quantity), 0)::numeric(10,2) as sum
        from public.order_items where order_id = p_order_id
    ) c
   where o.id = p_order_id;
end $$;

grant execute on function
  public.set_order_item_quantity(uuid, uuid, integer) to authenticated;

-- --------------------------------------------------------- staff directory

-- The PIN pad lists kitchen and cashier names to tap, and it has to do that
-- before anyone is signed in — so this one is deliberately public.
--
-- It exposes staff first names and role for a restaurant whose slug you
-- already know. It exposes no contact details and no secrets; passwords are
-- Supabase Auth's problem and are never in this table. If even the names are
-- too much for your setting, drop the grant to `anon` and have staff sign in
-- by typing their username instead.
create or replace function public.staff_directory(p_slug text)
returns table (id uuid, name text, role text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select s.id, s.name, s.role
    from public.staff s
    join public.restaurants r on r.id = s.restaurant_id
   where r.slug = p_slug
     and s.active
     and s.role <> 'ADMIN'
   order by s.name
$$;

grant execute on function public.staff_directory(text) to anon, authenticated;
