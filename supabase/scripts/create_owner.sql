-- ============================================================================
--  EZ Order — create an owner who signs in with an email and a password
-- ============================================================================
--
--  Run this in the Supabase SQL Editor. It adds an owner to a restaurant that
--  already exists.
--
--  The app cannot do this for the *first* owner, which is the whole reason the
--  script exists: creating staff needs an owner signed in, and before the first
--  one there is nobody to be signed in as. After that, use the app instead —
--  Manage → Staff → Add staff — because it enforces the same rules with better
--  error messages and does not require anybody to hold database credentials.
--
--  It reuses create_auth_user(), the same function provision_restaurant_with_email()
--  calls, so an owner made here is identical to one made any other way. Nothing
--  below writes to auth.users by hand; doing that produces accounts that look
--  right and cannot sign in.
--
--  EDIT THE FOUR VALUES BELOW, then Run with nothing selected.
--  (A selection makes the editor run only the highlighted text.)
-- ============================================================================

do $$
declare
  -- ---------------------------------------------------------------- EDIT ME
  c_slug     constant text := 'demo';                  -- which restaurant
  c_name     constant text := 'Restaurant Owner';      -- shown in the app
  c_email    constant text := 'owner@yourshop.com';    -- what they type to sign in
  c_password constant text := 'change-this-password';  -- at least 8 characters
  -- -------------------------------------------------------------------------

  v_restaurant_id uuid;
  v_email         text;
  v_user_id       uuid;
begin
  -- Same address check the app and 0012 use, so an address accepted here is
  -- one the app will accept too.
  v_email := public.normalize_login_email(c_email);
  if v_email is null then
    raise exception 'That does not look like an email address: %', c_email;
  end if;

  if length(coalesce(c_password, '')) < 8 then
    raise exception 'A password must be at least 8 characters';
  end if;

  if c_password = 'change-this-password' then
    raise exception 'Set a real password before running this';
  end if;

  select id into v_restaurant_id
    from public.restaurants
   where slug = lower(c_slug);

  if v_restaurant_id is null then
    raise exception 'No restaurant with the slug "%". Existing slugs: %',
      c_slug,
      (select coalesce(string_agg(slug, ', '), '(none)') from public.restaurants);
  end if;

  -- Sign-in matches the first account with the address typed, so a duplicate
  -- would lock the second owner out for good with nothing on screen to explain
  -- why. Refuse rather than create it.
  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'An account already uses %. To reset its password instead, '
      'see the block at the bottom of this file.', v_email;
  end if;

  v_user_id := public.create_auth_user(v_email, c_password);

  insert into public.staff (id, restaurant_id, name, role, username, email)
  values (v_user_id, v_restaurant_id, c_name, 'ADMIN', '', v_email);

  raise notice 'Owner % created for restaurant "%" — sign in with that address '
    'and the password you set above.', v_email, c_slug;
end $$;


-- ============================================================================
--  Check it worked
-- ============================================================================
--
--  staff.email is the app's copy; auth.users.email is what Supabase actually
--  authenticates against. They must match — set_my_login_email() moves both
--  together. If they have drifted, sign-in uses the auth one and the app shows
--  the other, which only ever surfaces when somebody is locked out.

select
  s.name,
  s.role,
  s.email                          as app_email,
  u.email                          as auth_email,
  s.email = u.email                as addresses_agree,
  s.active,
  u.last_sign_in_at
from public.staff s
join auth.users u on u.id = s.id
join public.restaurants r on r.id = s.restaurant_id
where r.slug = 'demo'
order by s.role, s.name;


-- ============================================================================
--  Reset an existing owner's password, without email
-- ============================================================================
--
--  The app has a proper forgotten-password flow that emails a link, and it is
--  the right answer for anybody who has an inbox. This is the way in when that
--  cannot work: the SMTP is not set up yet, or the address on the account is
--  one nobody can read any more.
--
--  Uncomment, set both values, and run.

-- update auth.users
--    set encrypted_password = extensions.crypt('the-new-password', extensions.gen_salt('bf')),
--        updated_at         = now()
--  where lower(email) = lower('owner@yourshop.com');


-- ============================================================================
--  Move an existing owner to a different address
-- ============================================================================
--
--  Prefer the app — Settings → Sign-in email — which moves the auth identity
--  and the staff row together and cannot leave them disagreeing. This is here
--  for the case where nobody can sign in to reach that screen.
--
--  All three statements or none: an auth identity that has moved while the
--  staff row has not is an account that authenticates and then cannot be found.

-- update auth.users      set email = lower('new@yourshop.com')
--  where lower(email) = lower('old@yourshop.com');
-- update auth.identities set identity_data = identity_data || '{"email":"new@yourshop.com"}'
--  where user_id = (select id from auth.users where lower(email) = lower('new@yourshop.com'));
-- update public.staff    set email = lower('new@yourshop.com')
--  where id = (select id from auth.users where lower(email) = lower('new@yourshop.com'));
