-- ============================================================================
--  EZ Order — getting back into the operator console
-- ============================================================================
--
--  Run these in the Supabase SQL Editor. Nothing here can be done from the app:
--  a platform admin is the account that authorises the console, so there is no
--  screen that would let one be created or reset by somebody who cannot already
--  get in.
--
--  `platform_admins` deliberately has no row level security policy — nothing
--  reads it from a client, ever. That is why the console cannot offer a
--  forgotten-password flow the way the restaurant side does, and why this file
--  exists instead.
--
--  A platform admin is two rows: one in auth.users, which does the signing in,
--  and one in platform_admins, which grants the authority. An account with only
--  one of them will authenticate and then be refused by every function on the
--  console, which is a confusing way to fail — so step 1 shows both.
--
--  Run step 1 first. It tells you which of steps 2 and 3 you need.
-- ============================================================================


-- ============================================================================
--  STEP 1 — who can get in, and with which address
-- ============================================================================
--  Run this on its own. If it returns a row, you have forgotten a password and
--  want step 2. If it returns nothing, there is no platform admin at all and
--  you want step 3.

select
  pa.name,
  u.email                              as sign_in_with,
  u.last_sign_in_at,
  u.email_confirmed_at is not null     as confirmed,
  -- A platform admin who is also restaurant staff is worth knowing about: the
  -- console and the restaurant app would both accept the same address, which
  -- is legal but rarely what anybody intended.
  exists (select 1 from public.staff s where s.id = pa.id) as also_restaurant_staff
from public.platform_admins pa
join auth.users u on u.id = pa.id
order by u.last_sign_in_at desc nulls last;


-- ============================================================================
--  STEP 2 — you know the address, you have forgotten the password
-- ============================================================================
--  Put the address from step 1 in, choose a new password, uncomment, run.

-- do $$
-- declare
--   c_email    constant text := 'you@yourdomain.com';   -- from step 1
--   c_password constant text := 'choose-a-real-one';    -- at least 8 characters
--   v_user_id  uuid;
-- begin
--   if length(c_password) < 8 then
--     raise exception 'A password must be at least 8 characters';
--   end if;
--
--   select u.id into v_user_id
--     from auth.users u
--     join public.platform_admins pa on pa.id = u.id
--    where lower(u.email) = lower(c_email);
--
--   if v_user_id is null then
--     raise exception 'No platform admin signs in with %. Run step 1 to see '
--       'which addresses do, or step 3 to make a new one.', c_email;
--   end if;
--
--   update auth.users
--      set encrypted_password = extensions.crypt(c_password, extensions.gen_salt('bf')),
--          updated_at         = now()
--    where id = v_user_id;
--
--   raise notice 'Password reset for %. Sign in at the console with it now.', c_email;
-- end $$;


-- ============================================================================
--  STEP 3 — there is no platform admin, or you want another one
-- ============================================================================
--  Uses create_auth_user(), the same function the app uses to make any account,
--  so the result is a normal Supabase user. Writing to auth.users by hand
--  instead produces accounts that look right everywhere and cannot sign in.

-- do $$
-- declare
--   c_email    constant text := 'you@yourdomain.com';
--   c_password constant text := 'choose-a-real-one';    -- at least 8 characters
--   c_name     constant text := 'Platform Operator';
--   v_user_id  uuid;
-- begin
--   if length(c_password) < 8 then
--     raise exception 'A password must be at least 8 characters';
--   end if;
--
--   select id into v_user_id from auth.users where lower(email) = lower(c_email);
--
--   if v_user_id is null then
--     -- Brand new account.
--     v_user_id := public.create_auth_user(lower(c_email), c_password);
--   else
--     -- The address already exists — most often a restaurant owner being given
--     -- console access as well. Keep the account, just set the password.
--     update auth.users
--        set encrypted_password = extensions.crypt(c_password, extensions.gen_salt('bf')),
--            updated_at         = now()
--      where id = v_user_id;
--   end if;
--
--   insert into public.platform_admins (id, name)
--   values (v_user_id, c_name)
--   on conflict (id) do update set name = excluded.name;
--
--   raise notice 'Platform admin % is ready.', c_email;
-- end $$;


-- ============================================================================
--  Taking access away
-- ============================================================================
--  Removes the authority without deleting the account, so an owner who was also
--  an operator keeps their restaurant.

-- delete from public.platform_admins
--  where id = (select id from auth.users where lower(email) = lower('them@yourdomain.com'));
