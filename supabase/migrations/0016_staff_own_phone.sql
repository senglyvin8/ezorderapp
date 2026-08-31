-- ============================================================================
--  EZ Order — a cashier with their own phone
-- ============================================================================
--
--  Kitchen and cashier accounts have always been PIN accounts: an address this
--  database generates and nobody can type, and a six digit secret. That is the
--  right shape for a tablet on the counter which five people share all shift.
--
--  It is the wrong shape for staff carrying their own phones, and it has a
--  consequence that is easy to miss. A PIN means nothing on its own — the app
--  has to know which restaurant before it can offer a list of names to tap. So
--  a personal phone must first be told the merchant, which means passing the
--  merchant ID around, and anybody holding it can see the staff roster and a
--  PIN pad to try against.
--
--  An owner has never had that problem: they sign in with their own address and
--  my_restaurant() works out where they work. This lets any member of staff do
--  the same.
--
--  Both stay. The owner chooses per person when they create the account:
--
--    an address and a password  ->  their own phone, signs in like an owner
--    a six digit PIN            ->  the shared tablet, taps a name
--
--  The only thing that changes below is that the address branch is no longer
--  reserved for ADMIN. Everything else — the guards, the derived address for
--  PIN accounts, the staff row — is 0012's, unchanged.
--
--  Run after 0001-0015. Safe to re-run.
-- ============================================================================

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
as $fn$
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
  v_email := public.normalize_login_email(p_email);

  if v_email is null and length(trim(coalesce(p_email,''))) > 0 then
    raise exception 'That does not look like an email address';
  end if;

  -- An owner must be reachable by something typeable: an address, or the
  -- username form that predates addresses.
  if p_role = 'ADMIN'
     and v_email is null
     and length(trim(coalesce(p_username,''))) = 0 then
    raise exception 'An owner needs an email address to sign in with';
  end if;

  if v_email is not null or p_role = 'ADMIN' then
    if length(coalesce(p_secret,'')) < 8 then
      raise exception 'A password must be at least 8 characters';
    end if;
    if v_email is not null
       and exists (select 1 from auth.users u
                    where lower(u.email) = v_email) then
      raise exception 'An account already uses %', v_email;
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
end $fn$;

grant execute on function
  public.create_staff_account(text, text, text, text, text) to authenticated;

-- --------------------------------------------------------- staff_directory
--
--  The list of names on the PIN pad, and the one function here that anonymous
--  callers may run: it has to be readable before anybody is anybody.
--
--  It already left admins out, for exactly the reason that now applies more
--  widely — they sign in by typing an address, so they are never tapped, and
--  listing them would offer a PIN pad against an account that has no PIN.
--
--  So the rule stops being about role and becomes about how somebody signs in.
--  Anyone with an address drops off the list.
--
--  Note what is *not* done here: the address is not returned so the client can
--  filter. This function answers to anon, and publishing every member of
--  staff's email address to whoever knows a restaurant's slug would be a
--  strange way to protect a PIN.

create or replace function public.staff_directory(p_slug text)
returns table (id uuid, name text, role text)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select s.id, s.name, s.role
    from public.staff s
    join public.restaurants r on r.id = s.restaurant_id
   where r.slug = p_slug
     and s.active
     and s.role <> 'ADMIN'
     and coalesce(s.email, '') = ''
   order by s.name
$fn$;

grant execute on function public.staff_directory(text) to anon, authenticated;
