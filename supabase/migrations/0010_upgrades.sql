-- ============================================================================
--  EZ Order — upgrade requests
-- ============================================================================
--
--  There is no billing. A merchant who wants a bigger plan has to reach you,
--  and until this file the only thing that happened when they hit a plan limit
--  was a red error message. That is a merchant standing at the counter with
--  money in their hand and nobody behind the till.
--
--  So: one row per merchant who has asked. They tap once, it lands here, and
--  the console shows it as a queue. The same row is what the app reads back to
--  say "we have your request, we will call you on 012 345 678" — a request
--  that vanishes feels exactly like being ignored.
--
--  Two rules worth stating up front:
--
--    * **One open request per merchant.** Tapping again edits the request
--      rather than filing a second one. A support queue with four copies of
--      the same ask is worse than no queue.
--    * **The plan change resolves it.** Moving a merchant onto the plan they
--      asked for closes their request automatically, because the alternative
--      is a queue full of things already done.
--
--  Run after 0001–0009. Safe to re-run.
-- ============================================================================

-- ------------------------------------------------------- how to reach you

-- Your phone number and Telegram handle, in the database rather than in the
-- app. You will change your Telegram handle one day and you should not need
-- an app release to do it — a merchant staring at a dead link is worse than
-- one who has to search for you.
--
-- Exactly one row, enforced by the primary key: `id` is a boolean that must be
-- true, so a second row cannot exist to disagree with the first.
create table if not exists public.platform_settings (
  id               boolean primary key default true check (id),
  support_phone    text not null default '',
  support_telegram text not null default '',
  -- Free text, shown under the buttons: "Mon–Sat, 8am–8pm".
  support_hours    text not null default '',
  updated_at       timestamptz not null default now()
);

insert into public.platform_settings (id) values (true)
  on conflict (id) do nothing;

alter table public.platform_settings enable row level security;

-- Readable by anyone, including a diner who will never see it. There is
-- nothing here that is not already printed on a business card, and the
-- alternative — an RPC — buys nothing.
drop policy if exists platform_settings_read on public.platform_settings;
create policy platform_settings_read on public.platform_settings
  for select using (true);

-- No write policy. Changed in the SQL editor, like membership of
-- platform_admins: it is your contact detail, not a merchant's.

-- --------------------------------------------------------------- the queue

create table if not exists public.upgrade_requests (
  id            uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null
                  references public.restaurants(id) on delete cascade,
  -- What they were on when they asked. Kept even after they move, so the
  -- console can say "Basic → Pro" a week later without guessing.
  from_plan     text not null check (from_plan in ('FREE','BASIC','PRO')),
  to_plan       text not null check (to_plan in ('FREE','BASIC','PRO')),
  -- What they were doing when they hit the wall. STAFF_CAP and TABLE_CAP come
  -- from the block itself; MANUAL is someone browsing the pricing screen.
  reason        text not null
                  check (reason in ('STAFF_CAP','TABLE_CAP','MANUAL')),
  -- Who to call. Defaults to the restaurant's own phone number, but a merchant
  -- may want you on their mobile rather than the shop line.
  contact_name  text not null default '',
  contact_phone text not null default '',
  note          text not null default '',
  status        text not null default 'NEW'
                  check (status in ('NEW','CONTACTED','DONE','DECLINED')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  handled_at    timestamptz,
  handled_by    uuid references auth.users(id) on delete set null,
  -- Your note to yourself, never shown to the merchant.
  handled_note  text not null default ''
);

-- One open request per merchant. A partial unique index rather than a plain
-- one: a merchant who upgraded in March and asks again in June is two rows,
-- and both are worth keeping.
create unique index if not exists upgrade_requests_one_open
  on public.upgrade_requests (restaurant_id)
  where status in ('NEW','CONTACTED');

create index if not exists upgrade_requests_queue
  on public.upgrade_requests (status, created_at);

alter table public.upgrade_requests enable row level security;

-- The merchant reads their own. Nobody writes through the table — writes go
-- through request_upgrade() below, so the restaurant_id is taken from the
-- caller's staff row and never from what the client sends.
drop policy if exists upgrade_requests_read_own on public.upgrade_requests;
create policy upgrade_requests_read_own on public.upgrade_requests
  for select using (restaurant_id = public.current_restaurant_id());

-- ------------------------------------------------------- filing a request

create or replace function public.request_upgrade(
  p_to_plan       text,
  p_reason        text,
  p_contact_name  text,
  p_contact_phone text,
  p_note          text default ''
)
returns public.upgrade_requests
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_restaurant uuid;
  v_plan       text;
  v_row        public.upgrade_requests;
begin
  -- The owner asks. A cashier who found the pricing screen does not commit
  -- their employer to a bill.
  if not public.can_manage_restaurant() then
    raise exception 'Only the owner can ask for a plan change';
  end if;

  v_restaurant := public.current_restaurant_id();
  select plan into v_plan from public.restaurants where id = v_restaurant;

  if p_to_plan not in ('FREE','BASIC','PRO') then
    raise exception 'Unknown plan %', p_to_plan;
  end if;
  if p_reason not in ('STAFF_CAP','TABLE_CAP','MANUAL') then
    raise exception 'Unknown reason %', p_reason;
  end if;

  -- Second tap edits the first request. `updated_at` moves so the console can
  -- tell a merchant who asked once from one who has now asked three times and
  -- is getting impatient; `created_at` does not, because how long they have
  -- been waiting is the whole point of the queue.
  update public.upgrade_requests
     set to_plan       = p_to_plan,
         reason        = p_reason,
         contact_name  = coalesce(nullif(trim(p_contact_name), ''), contact_name),
         contact_phone = coalesce(nullif(trim(p_contact_phone), ''), contact_phone),
         note          = p_note,
         updated_at    = now()
   where restaurant_id = v_restaurant
     and status in ('NEW','CONTACTED')
   returning * into v_row;

  if found then
    return v_row;
  end if;

  insert into public.upgrade_requests (
    restaurant_id, from_plan, to_plan, reason,
    contact_name, contact_phone, note
  ) values (
    v_restaurant, v_plan, p_to_plan, p_reason,
    trim(p_contact_name), trim(p_contact_phone), p_note
  )
  returning * into v_row;

  return v_row;
end $$;

grant execute on function
  public.request_upgrade(text, text, text, text, text) to authenticated;

-- The merchant's own open request, or nothing. Separate from the select
-- policy because the app asks for exactly this and should not have to know
-- which statuses count as open.
create or replace function public.my_upgrade_request()
returns public.upgrade_requests
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select * from public.upgrade_requests
   where restaurant_id = public.current_restaurant_id()
     and status in ('NEW','CONTACTED')
   order by created_at desc
   limit 1
$$;

grant execute on function public.my_upgrade_request() to authenticated;

-- Withdrawing. A merchant who asked by mistake, or who has since spoken to
-- you, should be able to clear it themselves rather than living with a card
-- on their pricing screen that they cannot dismiss.
create or replace function public.cancel_upgrade_request()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.can_manage_restaurant() then
    raise exception 'Only the owner can withdraw a plan change request';
  end if;

  update public.upgrade_requests
     set status     = 'DECLINED',
         handled_at = now(),
         updated_at = now()
   where restaurant_id = public.current_restaurant_id()
     and status in ('NEW','CONTACTED');
end $$;

grant execute on function public.cancel_upgrade_request() to authenticated;

-- ------------------------------------------------------- the operator's end

create or replace function public.platform_upgrade_requests()
returns table (
  id            uuid,
  restaurant_id uuid,
  merchant      text,
  slug          text,
  logo          text,
  merchant_phone text,
  from_plan     text,
  to_plan       text,
  reason        text,
  contact_name  text,
  contact_phone text,
  note          text,
  status        text,
  created_at    timestamptz,
  updated_at    timestamptz,
  handled_at    timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  -- Open ones first and oldest first within that: the queue is ordered by how
  -- long somebody has been waiting, not by how much they would pay.
  select r.id, r.restaurant_id, m.name, m.slug, m.logo, m.phone,
         r.from_plan, r.to_plan, r.reason,
         r.contact_name, r.contact_phone, r.note,
         r.status, r.created_at, r.updated_at, r.handled_at
    from public.upgrade_requests r
    join public.restaurants m on m.id = r.restaurant_id
   where public.is_platform_admin()
     -- Resolved requests stay visible for a fortnight. Long enough to see what
     -- you did last week, short enough that the queue is still a queue.
     and (r.status in ('NEW','CONTACTED')
          or r.handled_at > now() - interval '14 days')
   order by (r.status in ('NEW','CONTACTED')) desc, r.created_at
$$;

grant execute on function public.platform_upgrade_requests() to authenticated;

create or replace function public.platform_resolve_upgrade_request(
  p_id     uuid,
  p_status text,
  p_note   text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not a platform administrator';
  end if;
  if p_status not in ('NEW','CONTACTED','DONE','DECLINED') then
    raise exception 'Unknown status %', p_status;
  end if;

  update public.upgrade_requests
     set status       = p_status,
         handled_note = p_note,
         updated_at   = now(),
         -- Moving one back to CONTACTED reopens it, so the handled stamp has
         -- to come off as well or it would show as dealt with in the queue.
         handled_at   = case when p_status in ('DONE','DECLINED')
                             then now() else null end,
         handled_by   = auth.uid()
   where id = p_id;

  if not found then
    raise exception 'Unknown request';
  end if;
end $$;

grant execute on function
  public.platform_resolve_upgrade_request(uuid, text, text) to authenticated;

-- --------------------------------------------- changing the plan closes it

-- The operator's most likely path is to skip the queue entirely: read the
-- request, agree, change the plan. Without this the request they just granted
-- sits in the queue looking outstanding, and the merchant's app keeps saying
-- "we have your request" after they are already on Pro.
create or replace function public.close_upgrade_request_on_plan_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.plan is distinct from old.plan then
    update public.upgrade_requests
       set status     = 'DONE',
           handled_at = now(),
           updated_at = now()
     where restaurant_id = new.id
       and status in ('NEW','CONTACTED');
  end if;
  return new;
end $$;

drop trigger if exists restaurants_close_upgrade_request on public.restaurants;
create trigger restaurants_close_upgrade_request
  after update of plan on public.restaurants
  for each row execute function public.close_upgrade_request_on_plan_change();

-- ============================================================================
--  Set your contact details:
--
--    update public.platform_settings set
--      support_phone    = '+855 12 345 678',
--      support_telegram = 'https://t.me/yourhandle',
--      support_hours    = 'Mon–Sat, 8am–8pm',
--      updated_at       = now();
-- ============================================================================
