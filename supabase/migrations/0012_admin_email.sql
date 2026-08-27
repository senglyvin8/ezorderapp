-- ============================================================================
--  EZ Order — owners sign in with their own email address
-- ============================================================================
--
--  An admin's login address used to be manufactured:
--
--      admin@<slug>.staff.ezorder.app
--
--  That was a reasonable trick when a restaurant's app was compiled for that
--  restaurant. It stops being reasonable the moment an owner installs the app
--  from a store: the address is not one they would ever guess, it cannot
--  receive a password reset, and it only works if the device already knows
--  which restaurant it belongs to — which is exactly what the owner is trying
--  to establish.
--
--  So an owner now signs in with their own address. That is the default for
--  every admin created from here on, and it is what makes the rest work: an
--  address identifies the person, the person's staff row identifies the
--  restaurant, and a device can therefore be set up by somebody who knows only
--  their own email and password.
--
--  Nothing is taken away. Kitchen and cashier staff still tap a name and key
--  in a PIN — an address and a password on a shared tablet in a busy kitchen
--  would be a worse answer, not a better one. And admins created the old way
--  keep working: their derived address is untouched, and sign-in accepts
--  either form.
--
--  Run after 0001–0011. Safe to re-run.
-- ============================================================================

alter table public.staff add column if not exists email text not null default '';

comment on column public.staff.email is
  'The address an owner signs in with. Empty for kitchen and cashier staff, '
  'who are identified by a PIN, and for admins created before this migration, '
  'who still sign in with the derived <username>@<slug> address.';

-- Globally unique, not per restaurant, because auth.users.email is: two
-- restaurants cannot share an owner address even though they can each have an
-- "admin" username.
create unique index if not exists staff_email_key
  on public.staff (lower(email)) where email <> '';

-- ---------------------------------------------------------------- validating

-- Deliberately not RFC 5322. The only thing an over-strict pattern achieves is
-- turning away somebody whose address is unusual but real; the address is
-- proved by a sign-in working, not by matching a regex.
--
-- Mirrored in `EmailAddress.normalize` in lib/models/email_address.dart.
create or replace function public.normalize_login_email(p_raw text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when p_raw is null then null
    when lower(trim(p_raw)) ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
      then lower(trim(p_raw))
    else null
  end
$$;

grant execute on function public.normalize_login_email(text) to anon, authenticated;

-- --------------------------------------------------- which restaurant am I in

-- The other half of signing in with an address: the address says who you are,
-- and this says where you work. A device with no idea which restaurant it
-- serves can be set up by an owner who knows only their own credentials.
--
-- Returns nothing for a diner, which is the correct answer — an anonymous
-- session works for a restaurant, not in one.
create or replace function public.my_restaurant()
returns table (
  id   uuid,
  slug text,
  code text,
  name text,
  logo text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select r.id, r.slug, r.code, r.name, r.logo
    from public.restaurants r
   where r.id = public.current_restaurant_id()
$$;

grant execute on function public.my_restaurant() to authenticated;

-- ------------------------------------------------------------- making an admin

-- The signature changes, and `create or replace` cannot add a parameter to an
-- existing function without leaving both versions callable and ambiguous.
drop function if exists public.create_staff_account(text, text, text, text);

create or replace function public.create_staff_account(
  p_name     text,
  p_role     text,
  p_secret   text,
  p_username text default '',
  p_email    text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_restaurant_id uuid := public.current_restaurant_id();
  v_slug          text;
  v_user_id       uuid;
  v_email         text;
begin
  if not public.can_manage_restaurant() then
    raise exception 'You are not allowed to manage staff';
  end if;
  if p_role not in ('ADMIN','KITCHEN','CASHIER') then
    raise exception 'Unknown role %', p_role;
  end if;

  select slug into v_slug from public.restaurants where id = v_restaurant_id;

  if p_role = 'ADMIN' then
    v_email := public.normalize_login_email(p_email);

    -- An address is the default and the username is the fallback, rather than
    -- the other way round: a new owner should not be invited to invent a
    -- username that only this app will ever use.
    if v_email is null and length(trim(coalesce(p_username,''))) = 0 then
      raise exception 'An owner needs an email address to sign in with';
    end if;
    if v_email is null and length(trim(coalesce(p_email,''))) > 0 then
      raise exception 'That does not look like an email address';
    end if;
    if length(coalesce(p_secret,'')) < 8 then
      raise exception 'A password must be at least 8 characters';
    end if;

    v_user_id := public.create_auth_user(
      coalesce(v_email, public.staff_login_email(v_slug, lower(trim(p_username)))),
      p_secret);
  else
    if length(coalesce(p_secret,'')) <> 6 then
      raise exception 'A PIN must be 6 digits';
    end if;
    -- create_auth_user mints the id, so the address is built from a throwaway
    -- value and rewritten to the real id once we have it. The client derives
    -- the same address from staff_directory(), so the two always agree.
    v_user_id := public.create_auth_user(
      public.staff_login_email(v_slug, gen_random_uuid()::text), p_secret);
    update auth.users
       set email = public.staff_login_email(v_slug, v_user_id::text)
     where id = v_user_id;
    update auth.identities
       set identity_data = jsonb_build_object(
             'sub', v_user_id::text,
             'email', public.staff_login_email(v_slug, v_user_id::text))
     where user_id = v_user_id;
  end if;

  insert into public.staff (id, restaurant_id, name, role, username, email)
  values (
    v_user_id, v_restaurant_id, trim(p_name), p_role,
    case when p_role = 'ADMIN' then lower(trim(coalesce(p_username,''))) else '' end,
    coalesce(v_email, '')
  );

  return v_user_id;
end $$;

grant execute on function
  public.create_staff_account(text, text, text, text, text) to authenticated;

-- ------------------------------------------- an existing owner adopts an address

-- Without this, everything above applies only to restaurants provisioned from
-- today — every owner already using the service would be stuck with a
-- manufactured address forever. It moves the auth user as well as the staff
-- row, because the address they type is the one GoTrue matches on.
create or replace function public.set_my_login_email(p_email text)
returns text
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_email text := public.normalize_login_email(p_email);
begin
  if not public.can_manage_restaurant() then
    raise exception 'Only an owner signs in with an email address';
  end if;
  if v_email is null then
    raise exception 'That does not look like an email address';
  end if;
  if exists (
    select 1 from auth.users
     where lower(email) = v_email and id <> auth.uid()
  ) then
    raise exception 'Another account already uses that email address';
  end if;

  update auth.users
     set email = v_email,
         -- Confirmed on the spot. There is no mail being sent here: an owner
         -- who mistypes it finds out at the next sign-in and an admin can
         -- change it back, which is a smaller problem than an owner locked out
         -- waiting for a message that never arrives.
         email_confirmed_at = coalesce(email_confirmed_at, now()),
         updated_at = now()
   where id = auth.uid();

  update auth.identities
     set identity_data = coalesce(identity_data, '{}'::jsonb)
                         || jsonb_build_object('email', v_email)
   where user_id = auth.uid();

  update public.staff set email = v_email where id = auth.uid();

  return v_email;
end $$;

grant execute on function public.set_my_login_email(text) to authenticated;

-- ------------------------------------------------------- provisioning, updated

-- Same job as provision_restaurant(), with the owner identified by their own
-- address. The original stays where it is: it is what the older restaurants
-- were created with and re-running these files must not rewrite history.
create or replace function public.provision_restaurant_with_email(
  p_slug           text,
  p_name           text,
  p_owner_email    text,
  p_owner_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_restaurant_id uuid;
  v_user_id       uuid;
  v_email         text := public.normalize_login_email(p_owner_email);
begin
  if v_email is null then
    raise exception 'That does not look like an email address';
  end if;
  if length(coalesce(p_owner_password,'')) < 8 then
    raise exception 'Give the owner a password of at least 8 characters';
  end if;

  insert into public.restaurants (slug, name)
  values (lower(p_slug), p_name)
  returning id into v_restaurant_id;

  v_user_id := public.create_auth_user(v_email, p_owner_password);

  insert into public.staff (id, restaurant_id, name, role, username, email)
  values (v_user_id, v_restaurant_id, p_name || ' Owner', 'ADMIN', '', v_email);

  return v_restaurant_id;
end $$;

revoke execute on function
  public.provision_restaurant_with_email(text, text, text, text)
  from anon, authenticated;

-- The console creates merchants, so it takes the owner's address now too. The
-- parameter is renamed, which `create or replace` refuses, hence the drop.
drop function if exists public.platform_create_merchant(text, text, text, text);

create or replace function public.platform_create_merchant(
  p_slug           text,
  p_name           text,
  p_admin_email    text,
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
  return public.provision_restaurant_with_email(
    p_slug, p_name, p_admin_email, p_admin_password);
end $$;

grant execute on function
  public.platform_create_merchant(text, text, text, text) to authenticated;

-- ============================================================================
--  To give an existing owner a real address by hand, from the SQL editor:
--
--    update auth.users set email = 'owner@theirshop.com'
--     where id = '<their staff id>';
--    update auth.identities
--       set identity_data = identity_data || '{"email":"owner@theirshop.com"}'
--     where user_id = '<their staff id>';
--    update public.staff set email = 'owner@theirshop.com'
--     where id = '<their staff id>';
--
--  Or, far more easily, have them do it themselves in the app:
--  Settings → Sign-in email.
-- ============================================================================
