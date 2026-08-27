-- ============================================================================
--  EZ Order — dish photos move to Storage
-- ============================================================================
--
--  Photos were base64 in `menu_items.photo`, which meant every menu fetch
--  dragged every photo with it. Measured on a live project: 268 KB of JSON for
--  a single dish. Thirty dishes would be ~8 MB downloaded by every diner, on
--  every load, and would exhaust Supabase's 5 GB monthly egress after about
--  625 menu views.
--
--  A URL into a public Storage bucket is ~90 bytes instead, the image comes
--  from a CDN, and the browser caches it. Menu JSON drops to a couple of KB.
--
--  Run this after 0001–0004. Safe to re-run.
-- ============================================================================

-- The URL replaces the base64. `photo` is kept for now so an app build that
-- has not been updated yet keeps working, and so existing photos survive until
-- they are migrated; see the note at the bottom about dropping it.
alter table public.menu_items
  add column if not exists photo_url text;

-- ------------------------------------------------------------------ bucket

-- Public read: a dish photo is exactly as secret as the menu it is on, which
-- is to say not at all — a diner has to see it before they are anyone.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'menu-photos', 'menu-photos', true, 2097152,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
  set public             = true,
      file_size_limit    = 2097152,
      allowed_mime_types = array['image/jpeg','image/png','image/webp'];

-- ------------------------------------------------------------------ access

-- Files are laid out as `<restaurant_id>/<uuid>.<ext>`, so the first path
-- segment is what scopes a write to the restaurant the caller belongs to.
-- An admin of one restaurant cannot write into another's folder.

drop policy if exists menu_photos_read on storage.objects;
create policy menu_photos_read on storage.objects
  for select using (bucket_id = 'menu-photos');

drop policy if exists menu_photos_insert on storage.objects;
create policy menu_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'menu-photos'
    and public.can_manage_restaurant()
    and (storage.foldername(name))[1] = public.current_restaurant_id()::text
  );

drop policy if exists menu_photos_update on storage.objects;
create policy menu_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'menu-photos'
    and public.can_manage_restaurant()
    and (storage.foldername(name))[1] = public.current_restaurant_id()::text
  );

drop policy if exists menu_photos_delete on storage.objects;
create policy menu_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'menu-photos'
    and public.can_manage_restaurant()
    and (storage.foldername(name))[1] = public.current_restaurant_id()::text
  );

-- ============================================================================
--  Once every dish has a photo_url and every device is on a build that reads
--  it, the old column can go:
--
--      alter table public.menu_items drop column photo;
--
--  Check first — this must return 0:
--
--      select count(*) from public.menu_items
--       where photo is not null and photo_url is null;
-- ============================================================================
