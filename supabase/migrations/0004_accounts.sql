-- ============================================================================
--  EZ Order — staff accounts
-- ============================================================================
--
--  Staff are real Supabase Auth users, so row level security can trust
--  `auth.uid()`. They never type an email address, though: the app derives one
--  from what they do type.
--
--      admin            <username>@<slug>.staff.ezorder.app
--      kitchen/cashier  <staff-id>@<slug>.staff.ezorder.app
--
--  Both are derivable by the client with no lookup — the admin's from the
--  username they type, everyone else's from the id in staff_directory(). That
--  matters: it means there is no "does this username exist" endpoint to probe.
--
--  Creating an auth user normally needs the service_role key, which must never
--  be in a phone app. These functions are SECURITY DEFINER instead, so an
--  admin signed in with the anon key can create staff for their own restaurant
--  and nobody else's.
-- ============================================================================

-- Derives the login address. Kept in SQL as well as Dart so both agree.
create or replace function public.staff_login_email(
  p_slug  text,
  p_local text
)
returns text language sql immutable
set search_path = public, pg_temp
as $$ select lower(p_local) || '@' || lower(p_slug) || '.staff.ezorder.app' $$;

grant execute on function public.staff_login_email(text, text) to anon, authenticated;

-- ---------------------------------------------------- creating an auth user
--
-- Writes the two rows GoTrue expects: the user, and an `email` identity. The
-- identities table has gained columns across GoTrue versions, so the insert is
-- built dynamically from what actually exists in this project rather than
-- assuming one particular version.
create or replace function public.create_auth_user(
  p_email    text,
  p_password text
)
returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_id  uuid := gen_random_uuid();
  v_cols text := 'user_id, identity_data, provider, last_sign_in_at, created_at, updated_at';
  v_vals text := '$1, $2, ''email'', now(), now(), now()';
begin
  if p_password is null or length(p_password) < 6 then
    raise exception 'A password or PIN must be at least 6 characters';
  end if;
  if exists (select 1 from auth.users where lower(email) = lower(p_email)) then
    raise exception 'Another account already uses that username';
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated',
    'authenticated', lower(p_email), crypt(p_password, gen_salt('bf')),
    now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    now(), now(), '', '', '', ''
  );

  -- `id` and `provider_id` appeared in later GoTrue versions.
  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'identities'
                and column_name = 'id') then
    v_cols := 'id, ' || v_cols;
    v_vals := 'gen_random_uuid(), ' || v_vals;
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'auth' and table_name = 'identities'
                and column_name = 'provider_id') then
    v_cols := v_cols || ', provider_id';
    v_vals := v_vals || ', $1::text';
  end if;

  execute format('insert into auth.identities (%s) values (%s)', v_cols, v_vals)
    using v_id, jsonb_build_object('sub', v_id::text, 'email', lower(p_email));

  return v_id;
end $$;

-- Never callable from a client; only from the functions below.
revoke execute on function public.create_auth_user(text, text) from anon, authenticated;

-- ------------------------------------------------------ bootstrap: run once
--
-- Creates a restaurant and its first admin. This is the only function you call
-- by hand, from the SQL editor, because until it has run there is no admin to
-- authorise anything.
--
--   select public.provision_restaurant('demo', 'ABC Restaurant',
--                                      'admin', 'a-long-password');
create or replace function public.provision_restaurant(
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
declare
  v_restaurant_id uuid;
  v_user_id       uuid;
begin
  if length(coalesce(p_admin_password,'')) < 8 then
    raise exception 'Give the owner a password of at least 8 characters';
  end if;

  insert into public.restaurants (slug, name)
  values (lower(p_slug), p_name)
  returning id into v_restaurant_id;

  v_user_id := public.create_auth_user(
    public.staff_login_email(p_slug, p_admin_username), p_admin_password);

  insert into public.staff (id, restaurant_id, name, role, username)
  values (v_user_id, v_restaurant_id, p_name || ' Owner', 'ADMIN',
          lower(p_admin_username));

  return v_restaurant_id;
end $$;

revoke execute on function
  public.provision_restaurant(text, text, text, text) from anon, authenticated;

-- ------------------------------------------------------------ manage staff

create or replace function public.create_staff_account(
  p_name     text,
  p_role     text,
  p_secret   text,
  p_username text default ''
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
  v_local         text;
begin
  if not public.can_manage_restaurant() then
    raise exception 'You are not allowed to manage staff';
  end if;
  if p_role not in ('ADMIN','KITCHEN','CASHIER') then
    raise exception 'Unknown role %', p_role;
  end if;
  if p_role = 'ADMIN' and length(trim(coalesce(p_username,''))) = 0 then
    raise exception 'An admin needs a username';
  end if;

  select slug into v_slug from public.restaurants where id = v_restaurant_id;

  -- An admin's address comes from their username so they can sign in by
  -- typing it. Everyone else's comes from their id, which the PIN pad already
  -- has from staff_directory().
  if p_role = 'ADMIN' then
    v_local := lower(trim(p_username));
    v_user_id := public.create_auth_user(
      public.staff_login_email(v_slug, v_local), p_secret);
  else
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

  insert into public.staff (id, restaurant_id, name, role, username)
  values (v_user_id, v_restaurant_id, trim(p_name), p_role,
          case when p_role = 'ADMIN' then lower(trim(p_username)) else '' end);

  return v_user_id;
end $$;

grant execute on function
  public.create_staff_account(text, text, text, text) to authenticated;

create or replace function public.reset_staff_secret(
  p_staff_id uuid,
  p_secret   text
)
returns void language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.can_manage_restaurant() then
    raise exception 'You are not allowed to manage staff';
  end if;
  if not exists (
    select 1 from public.staff
     where id = p_staff_id and restaurant_id = public.current_restaurant_id()
  ) then
    raise exception 'That account is not yours to change';
  end if;
  if length(coalesce(p_secret,'')) < 6 then
    raise exception 'A password or PIN must be at least 6 characters';
  end if;

  update auth.users
     set encrypted_password = crypt(p_secret, gen_salt('bf')), updated_at = now()
   where id = p_staff_id;
end $$;

grant execute on function public.reset_staff_secret(uuid, text) to authenticated;

-- Locking every admin out would be unrecoverable without the SQL editor, so
-- the last active one is protected — same guard the prototype had.
create or replace function public.assert_not_last_admin(p_staff_id uuid)
returns void language plpgsql
set search_path = public, pg_temp
as $$
begin
  if exists (select 1 from public.staff
              where id = p_staff_id and role = 'ADMIN' and active)
     and not exists (
       select 1 from public.staff
        where restaurant_id = public.current_restaurant_id()
          and role = 'ADMIN' and active and id <> p_staff_id
     )
  then
    raise exception 'There must be at least one active admin';
  end if;
end $$;

create or replace function public.set_staff_active(
  p_staff_id uuid,
  p_active   boolean
)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if not public.can_manage_restaurant() then
    raise exception 'You are not allowed to manage staff';
  end if;
  if not exists (
    select 1 from public.staff
     where id = p_staff_id and restaurant_id = public.current_restaurant_id()
  ) then
    raise exception 'That account is not yours to change';
  end if;
  if not p_active then
    perform public.assert_not_last_admin(p_staff_id);
  end if;

  update public.staff set active = p_active where id = p_staff_id;
end $$;

create or replace function public.delete_staff_account(p_staff_id uuid)
returns void language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
begin
  if not public.can_manage_restaurant() then
    raise exception 'You are not allowed to manage staff';
  end if;
  if p_staff_id = auth.uid() then
    raise exception 'You cannot delete the account you are signed in with';
  end if;
  if not exists (
    select 1 from public.staff
     where id = p_staff_id and restaurant_id = public.current_restaurant_id()
  ) then
    raise exception 'That account is not yours to change';
  end if;
  perform public.assert_not_last_admin(p_staff_id);

  -- staff.id references auth.users on delete cascade, so this removes both.
  delete from auth.users where id = p_staff_id;
end $$;

grant execute on function public.set_staff_active(uuid, boolean) to authenticated;
grant execute on function public.delete_staff_account(uuid)      to authenticated;
