-- ============================================================================
--  EZ Order — placing the same order twice
-- ============================================================================
--
--  A restaurant's wifi drops during service. The app now holds an order on the
--  device and sends it when the connection returns, which is the right answer
--  to a dropped connection and introduces a worse problem than the one it
--  solves.
--
--  The problem is the ambiguous failure. If the network dies *after* this
--  function has committed but *before* the reply reaches the phone, the app
--  cannot tell whether the order was placed. Both outcomes look identical from
--  out there: silence. Retrying then puts the same food on the pass twice and
--  charges the table for it; not retrying loses an order that was never made.
--  Neither is acceptable, and no amount of client cleverness can decide which
--  happened — only the database knows.
--
--  So the client mints a key before its first attempt and keeps it across every
--  retry. This function recognises a key it has already seen and hands back the
--  order it already made, rather than making a second one. A retry becomes
--  safe to do as often as you like.
--
--  The key is scoped per restaurant rather than globally: it is generated on a
--  phone, and two restaurants are not sharing a random namespace by agreement.
--
--  Run after 0001–0012. Safe to re-run.
-- ============================================================================

alter table public.orders
  add column if not exists client_key text;

-- Partial, so the rows that predate this migration — all of them null — do not
-- collide with each other.
create unique index if not exists orders_client_key_unique
  on public.orders (restaurant_id, client_key)
  where client_key is not null;

comment on column public.orders.client_key is
  'Idempotency key minted by the client before its first attempt. Lets a retry '
  'after an ambiguous network failure return the original order instead of '
  'placing a second one.';

-- ---------------------------------------------------------------- place_order
--
--  Redefined here rather than in 0008 so the change is readable on its own.
--  The only difference is the new p_client_key argument and the lookup at the
--  top; everything else is 0008's body unchanged.

create or replace function public.place_order(
  p_restaurant_id uuid,
  p_type          text,
  p_table_id      uuid,
  p_note          text,
  p_items         jsonb,
  p_client_key    text default null
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

  -- Already have it. Say so quietly and hand back the same order: a retry is
  -- the app being careful, not an error worth reporting to anybody.
  if p_client_key is not null then
    select id into v_order_id
      from public.orders
     where restaurant_id = p_restaurant_id
       and client_key = p_client_key;
    if v_order_id is not null then
      return v_order_id;
    end if;
  end if;

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
    status, customer_note, placed_by, customer_id, client_key
  ) values (
    p_restaurant_id, v_number, p_type, p_table_id, v_table_number,
    'NEW', nullif(trim(coalesce(p_note,'')), ''), v_placed_by,
    case when v_placed_by is null then auth.uid() end,
    p_client_key
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
  public.place_order(uuid, text, uuid, text, jsonb, text) to anon, authenticated;

-- NOTE: the five-argument form from 0008 must NOT be left in place. Two
-- overloads that differ only by an argument with a default are ambiguous to
-- PostgREST, and every call using the original five names is refused with
-- PGRST203 before it reaches any of the rules below. 0014 drops it. Run both.
