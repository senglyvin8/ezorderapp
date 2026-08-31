-- ============================================================================
--  EZ Order — a restaurant asks to join, and you say yes
-- ============================================================================
--
--  Until now a merchant existed because somebody with console access made one.
--  Fine for a handful, impossible for a hundred: every restaurant that wants to
--  try this has to find a human first and describe what they want down a phone.
--
--  So they fill in a form instead — email, password, what the place is called —
--  and it lands in the console as a request. You approve it and the restaurant
--  exists. The human is still in the loop; they are no longer the way the
--  information gets collected.
--
--  ------------------------------------------------------------------------
--  WHERE THE PASSWORD LIVES
--  ------------------------------------------------------------------------
--
--  Nowhere in this schema. The obvious design — hold the password on the
--  request row until somebody approves it — means a table of plaintext
--  credentials belonging to people who are not yet customers, readable by
--  anyone who ever gets a look at the database.
--
--  Instead the account is created when the form is submitted, by
--  create_auth_user(), which hashes it into auth.users exactly as every other
--  account here is hashed. The request row holds a reference to that account
--  and nothing secret at all.
--
--  The account is inert until approved. It can sign in and it has no staff row,
--  so my_restaurant() returns nothing, current_restaurant_id() is null, and
--  every guarded function in this database refuses it. Approval is the moment
--  it becomes staff of a restaurant that exists.
--
--  ------------------------------------------------------------------------
--  WHY THE FORM IS OPEN AND THE APPROVAL IS NOT
--  ------------------------------------------------------------------------
--
--  request_signup() is granted to anon, because somebody signing up is by
--  definition not signed in. All it can do is create an account that does
--  nothing. Everything that grants real power — approving, rejecting, reading
--  the queue — checks is_platform_admin().
--
--  Run after 0001-0014. Safe to re-run.
-- ============================================================================


-- ------------------------------------------------------------------ slugify
--
--  A restaurant's slug goes into its printed QR codes, so it is chosen once
--  and changing it later means reprinting them.

create or replace function public.slugify(p_name text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $fn$
  select
    trim(both '-' from
      left(
        trim(both '-' from
          regexp_replace(
            regexp_replace(
              -- Apostrophes come out rather than becoming separators, so
              -- "Sengly's Kitchen" is senglys-kitchen, not sengly-s-kitchen.
              -- Both the straight one and the curly one a phone produces.
              regexp_replace(lower(coalesce(p_name, '')), '[''’`]', '', 'g'),
              '[^a-z0-9]+', '-', 'g'),
            '-+', '-', 'g')),
        40));
$fn$;

grant execute on function public.slugify(text) to anon, authenticated;


-- ---------------------------------------------------------- signup_requests

create table if not exists public.signup_requests (
  id              uuid primary key default gen_random_uuid(),
  -- The account created when the form was submitted. Cascades, so deleting a
  -- rejected applicant's account takes the request with it.
  user_id         uuid not null references auth.users(id) on delete cascade,
  email           text not null,
  restaurant_name text not null,
  slug            text not null,
  owner_name      text not null default '',
  status          text not null default 'PENDING'
                    check (status in ('PENDING','APPROVED','REJECTED')),
  -- Why it was turned down, in words the applicant could be shown.
  note            text not null default '',
  restaurant_id   uuid references public.restaurants(id) on delete set null,
  created_at      timestamptz not null default now(),
  reviewed_at     timestamptz,
  reviewed_by     uuid references auth.users(id) on delete set null
);

-- One open request per account. Somebody rejected may apply again; somebody
-- still waiting may not queue up a second.
create unique index if not exists signup_requests_one_open
  on public.signup_requests (user_id)
  where status = 'PENDING';

create index if not exists signup_requests_pending_idx
  on public.signup_requests (created_at)
  where status = 'PENDING';

alter table public.signup_requests enable row level security;

-- No policy, deliberately. Nothing reads this table directly from a client:
-- the applicant sees their own row through my_signup_request(), the console
-- sees the queue through platform_signup_requests(). A policy here would be a
-- second place for the rules to live and disagree.


-- ----------------------------------------------------------- slug_available
--
--  Says only yes or no. It is callable by anybody, and naming who holds a slug
--  would turn it into a directory of every restaurant on the service.

create or replace function public.slug_available(p_slug text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select
    p_slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'
    and not exists (select 1 from public.restaurants r where r.slug = p_slug)
    -- A slug spoken for by a request nobody has answered yet is not free
    -- either, or two people fill in the same form and one is disappointed at
    -- approval time rather than at typing time.
    and not exists (
      select 1 from public.signup_requests s
       where s.slug = p_slug and s.status = 'PENDING');
$fn$;

grant execute on function public.slug_available(text) to anon, authenticated;


-- ----------------------------------------------------------- request_signup

create or replace function public.request_signup(
  p_email           text,
  p_password        text,
  p_restaurant_name text,
  p_slug            text,
  p_owner_name      text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_email text := public.normalize_login_email(p_email);
  v_slug  text;
  v_uid   uuid;
  v_id    uuid;
begin
  if v_email is null then
    raise exception 'That does not look like an email address';
  end if;
  if length(coalesce(p_password, '')) < 8 then
    raise exception 'A password must be at least 8 characters';
  end if;
  if length(trim(coalesce(p_restaurant_name, ''))) = 0 then
    raise exception 'Give the restaurant a name';
  end if;

  -- Never touch an account that already exists, or this form becomes a way to
  -- overwrite somebody's password by knowing their address.
  if exists (select 1 from auth.users u where lower(u.email) = v_email) then
    raise exception 'An account already uses %. Sign in instead.', v_email;
  end if;

  v_slug := public.slugify(
    coalesce(nullif(trim(p_slug), ''), p_restaurant_name));

  if v_slug !~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$' then
    raise exception 'That web address will not work. Use letters and numbers.';
  end if;
  if not public.slug_available(v_slug) then
    raise exception 'The address "%" is taken. Try another.', v_slug;
  end if;

  -- Hashed into auth.users, never held here. See the note at the top.
  v_uid := public.create_auth_user(v_email, p_password);

  insert into public.signup_requests
    (user_id, email, restaurant_name, slug, owner_name)
  values
    (v_uid, v_email, trim(p_restaurant_name), v_slug,
     trim(coalesce(p_owner_name, '')))
  returning id into v_id;

  return v_id;
end $fn$;

grant execute on function
  public.request_signup(text, text, text, text, text) to anon, authenticated;


-- --------------------------------------------------------- my_signup_request
--
--  So somebody who signs in while still waiting is told what is happening,
--  rather than meeting an app that refuses everything without saying why.

create or replace function public.my_signup_request()
returns table (
  status          text,
  restaurant_name text,
  slug            text,
  note            text,
  created_at      timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select s.status, s.restaurant_name, s.slug, s.note, s.created_at
    from public.signup_requests s
   where s.user_id = auth.uid()
   order by s.created_at desc
   limit 1;
$fn$;

grant execute on function public.my_signup_request() to authenticated;


-- --------------------------------------------------------- the console's side

create or replace function public.platform_signup_requests()
returns table (
  id              uuid,
  email           text,
  restaurant_name text,
  slug            text,
  owner_name      text,
  status          text,
  note            text,
  created_at      timestamptz,
  reviewed_at     timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;
  return query
    select s.id, s.email, s.restaurant_name, s.slug, s.owner_name,
           s.status, s.note, s.created_at, s.reviewed_at
      from public.signup_requests s
     order by (s.status = 'PENDING') desc, s.created_at desc;
end $fn$;

grant execute on function public.platform_signup_requests() to authenticated;


create or replace function public.platform_approve_signup(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_req public.signup_requests%rowtype;
  v_id  uuid;
  v_n   integer;
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;

  select * into v_req from public.signup_requests where id = p_id;
  if v_req.id is null then
    raise exception 'No such request';
  end if;
  if v_req.status <> 'PENDING' then
    raise exception 'That request was already %', lower(v_req.status);
  end if;

  -- Between the form being filled in and this moment somebody else may have
  -- taken the address. Checked here rather than trusted from the request.
  if exists (select 1 from public.restaurants r where r.slug = v_req.slug) then
    raise exception 'The address "%" has been taken since this was asked for',
      v_req.slug;
  end if;

  insert into public.restaurants (slug, name)
  values (v_req.slug, v_req.restaurant_name)
  returning id into v_id;

  insert into public.staff (id, restaurant_id, name, role, username, email)
  values (v_req.user_id, v_id,
          coalesce(nullif(v_req.owner_name, ''), 'Owner'),
          'ADMIN', '', v_req.email);

  -- Five tables, the free plan's allowance. A restaurant with none cannot take
  -- a dine-in order, and the first thing a new owner wants is a QR code to
  -- point a phone at. qr_id must match RestaurantTable.qrIdFor() in
  -- restaurant_table.dart: 'restaurant-<slug>-table-<number>'.
  for v_n in 1..5 loop
    insert into public.restaurant_tables (restaurant_id, number, name, qr_id)
    values (v_id, lpad(v_n::text, 2, '0'),
            'Table ' || lpad(v_n::text, 2, '0'),
            'restaurant-' || v_req.slug || '-table-' || lpad(v_n::text, 2, '0'));
  end loop;

  -- No menu. It is their food, and a seeded one would have to be deleted dish
  -- by dish before they could put their own in.

  update public.signup_requests
     set status = 'APPROVED', restaurant_id = v_id,
         reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_id;

  return v_id;
end $fn$;

grant execute on function public.platform_approve_signup(uuid) to authenticated;


create or replace function public.platform_reject_signup(
  p_id     uuid,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_status text;
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;

  select status into v_status from public.signup_requests where id = p_id;
  if v_status is null then
    raise exception 'No such request';
  end if;
  if v_status <> 'PENDING' then
    raise exception 'That request was already %', lower(v_status);
  end if;

  -- The account stays. Somebody turned down over a bad slug should be able to
  -- sign in and read why, rather than finding their password stopped working.
  update public.signup_requests
     set status = 'REJECTED', note = coalesce(p_reason, ''),
         reviewed_at = now(), reviewed_by = auth.uid()
   where id = p_id;
end $fn$;

grant execute on function public.platform_reject_signup(uuid, text) to authenticated;
