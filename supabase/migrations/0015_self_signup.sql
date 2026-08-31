-- ============================================================================
--  EZ Order — a restaurant can sign itself up
-- ============================================================================
--
--  Until now a merchant existed because somebody with console access made one.
--  That is fine for a handful and impossible for a hundred: every restaurant
--  that wants to try the product has to find a human first.
--
--  So: prove an email address, name the restaurant, and it exists on the free
--  plan. The console stops being the only way in and becomes the place you
--  moderate from — it can already suspend.
--
--  ------------------------------------------------------------------------
--  THE GUARD THAT MATTERS
--  ------------------------------------------------------------------------
--
--  Every diner is signed in anonymously. That is how row level security scopes
--  "my orders" to one phone, and it means the `authenticated` role in this
--  database is mostly made of strangers who scanned a sticker. Granting
--  anything to `authenticated` grants it to them.
--
--  So claim_restaurant() checks three things beyond being signed in:
--
--    * not an anonymous session — the JWT says so, and a diner's does
--    * a confirmed email address — the code they typed is what confirms it
--    * not already staff anywhere — one account, one restaurant
--
--  Drop any one of those and a scanned QR code becomes a way to create
--  restaurants.
--
--  Run after 0001–0014. Safe to re-run.
-- ============================================================================


-- ------------------------------------------------------------------ slugify
--
--  A restaurant's slug is in its printed QR codes, so it is chosen once and
--  changing it means reprinting. Derived from the name here, shown to the
--  owner before they commit, and theirs to correct.

create or replace function public.slugify(p_name text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select
    -- Trim to the length the column allows, then trim again: cutting at 40 can
    -- leave a trailing hyphen, which the check constraint rejects.
    trim(both '-' from
      left(
        trim(both '-' from
          regexp_replace(
            regexp_replace(
              -- Apostrophes come out rather than becoming separators:
              -- "Sengly's Kitchen" is senglys-kitchen, not sengly-s-kitchen.
              -- Both the straight one and the curly one a phone keyboard
              -- actually produces.
              regexp_replace(lower(coalesce(p_name, '')), '[''\u2019`]', '', 'g'),
              '[^a-z0-9]+', '-', 'g'),
            '-+', '-', 'g')),
        40));
$$;

grant execute on function public.slugify(text) to anon, authenticated;


-- ----------------------------------------------------------- slug_available
--
--  So the sign-up screen can say "taken" while somebody types rather than
--  after they commit. Deliberately tells you nothing except yes or no: it is
--  a public function, and returning the name of whoever holds a slug would
--  turn it into a directory.

create or replace function public.slug_available(p_slug text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p_slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'
    and not exists (select 1 from public.restaurants r where r.slug = p_slug);
$$;

grant execute on function public.slug_available(text) to anon, authenticated;


-- --------------------------------------------------------- claim_restaurant

create or replace function public.claim_restaurant(
  p_restaurant_name text,
  p_slug            text,
  p_owner_name      text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text;
  v_slug  text;
  v_id    uuid;
  v_n     integer;
begin
  if v_uid is null then
    raise exception 'Sign in first';
  end if;

  -- A diner's session. Every phone that scans a table has one, so this is the
  -- difference between self-signup and letting the public write to the
  -- restaurants table.
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Confirm an email address before creating a restaurant';
  end if;

  select u.email into v_email
    from auth.users u
   where u.id = v_uid
     and u.email_confirmed_at is not null
     and coalesce(u.email, '') <> '';

  if v_email is null then
    raise exception 'Confirm your email address before creating a restaurant';
  end if;

  -- One account, one restaurant. Somebody who runs two shops makes a second
  -- account; letting one account hold two would mean deciding which one
  -- my_restaurant() means, and every screen in the app assumes there is one.
  if exists (select 1 from public.staff s where s.id = v_uid) then
    raise exception 'That account already works for a restaurant';
  end if;

  if length(trim(coalesce(p_restaurant_name, ''))) = 0 then
    raise exception 'Give the restaurant a name';
  end if;

  v_slug := public.slugify(
    coalesce(nullif(trim(p_slug), ''), p_restaurant_name));

  if v_slug !~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$' then
    raise exception 'That address will not work. Use letters and numbers.';
  end if;

  if exists (select 1 from public.restaurants r where r.slug = v_slug) then
    raise exception 'The address "%" is taken. Try another.', v_slug;
  end if;

  insert into public.restaurants (slug, name)
  values (v_slug, trim(p_restaurant_name))
  returning id into v_id;

  insert into public.staff (id, restaurant_id, name, role, username, email)
  values (
    v_uid,
    v_id,
    coalesce(nullif(trim(p_owner_name), ''), 'Owner'),
    'ADMIN',
    '',
    v_email
  );

  -- Five tables, because a restaurant with none cannot take a dine-in order
  -- and the first thing a new owner wants is a QR code to point a phone at.
  -- Five is what the free plan allows, so nobody starts over a cap.
  --
  -- qr_id must match what the app builds when it adds a table later, or a
  -- restaurant would end up with two spellings of the same thing:
  -- RestaurantTable.qrIdFor() in restaurant_table.dart is 'restaurant-<slug>-
  -- table-<number>'. Change one and you must change the other.
  for v_n in 1..5 loop
    insert into public.restaurant_tables (restaurant_id, number, name, qr_id)
    values (
      v_id,
      lpad(v_n::text, 2, '0'),
      'Table ' || lpad(v_n::text, 2, '0'),
      'restaurant-' || v_slug || '-table-' || lpad(v_n::text, 2, '0')
    );
  end loop;

  -- No menu. It is their food, and a seeded one would have to be deleted dish
  -- by dish before they could put their own in.

  return v_id;
end $$;

grant execute on function
  public.claim_restaurant(text, text, text) to authenticated;
