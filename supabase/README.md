# Putting EZ Order on Supabase

With no configuration, EZ Order runs entirely on the device: a seeded demo
restaurant in SharedPreferences. Everything below turns it into a real product
— one database behind every device, so the kitchen tablet, the till and the
diner's phone are three views of one restaurant instead of three unrelated
apps, and roles are enforced by Postgres rather than by the app being polite.

You need about ten minutes and a free Supabase account.

---

## 1. Create the project

1. Go to <https://supabase.com/dashboard> and **New project**.
2. Pick a region close to the restaurant — every tap the staff make is a round
   trip, and a kitchen board in Phnom Penh talking to Virginia will feel it.
3. Save the database password somewhere. You will not need it for the app, but
   you will need it if you ever want to connect with `psql`.

## 2. Run the migrations

Open **SQL Editor** in the dashboard and paste `migrations/all_in_one.sql`,
which is every file below concatenated in order. Running the numbered files
one at a time does exactly the same thing, and is worth doing if you want to
read what each one adds before it lands:

| # | File | What it does |
| --- | --- | --- |
| 1 | `migrations/0001_schema.sql` | Tables, indexes, realtime publication |
| 2 | `migrations/0002_policies.sql` | Row level security |
| 3 | `migrations/0003_rpc.sql` | Order state machine (Rules 6, 7, 12) |
| 4 | `migrations/0004_accounts.sql` | Staff accounts |
| 5 | `migrations/0005_photos.sql` | Dish photos in Storage |
| 6 | `migrations/0006_plans.sql` | Free / Basic / Pro, and the caps |
| 7 | `migrations/0007_hardening.sql` | Tightening on what a client may write |
| 8 | `migrations/0008_platform.sql` | The operator console |
| 9 | `migrations/0009_platform_detail.sql` | What the console needs to triage |
| 10 | `migrations/0010_upgrades.sql` | Upgrade requests, and how to reach you |
| 11 | `migrations/0011_merchant_code.sql` | The merchant ID staff sign in with |
| 12 | `migrations/0012_admin_email.sql` | Owners sign in with their own email |

Each should report success with no rows. If one fails, stop — later files
depend on earlier ones, and running them out of order leaves a half-built
schema that is more annoying to diagnose than to redo.

After the last one, put your own contact details in — they are what a merchant
who wants a bigger plan sees, and they are blank until you do:

```sql
update public.platform_settings set
  support_phone    = '+855 12 345 678',
  support_telegram = 'https://t.me/yourhandle',
  support_hours    = 'Mon–Sat, 8am–8pm',
  updated_at       = now();
```

## 3. Turn on anonymous sign-in

**Authentication → Sign In / Providers → Anonymous sign-ins → enable.**

This is not optional, and it is worth understanding why. A diner has no
account and never will — that is the whole premise. But row level security
needs *some* identity to scope "my orders" to, or every diner could read every
other diner's order. An anonymous session is that identity: it costs the diner
nothing, asks them for nothing, and is what keeps table 6 from reading table 4's
bill.

## 4. Create your restaurant and its first owner

Back in the SQL editor. This is the one function you call by hand, because
until it has run there is no admin to authorise anything:

```sql
select public.provision_restaurant(
  'demo',                 -- slug: lowercase, url-safe, appears in QR links
  'ABC Restaurant',       -- display name
  'admin',                -- owner's username
  'choose-a-real-password'
);
```

Pick a real password. This account can edit the menu, read the takings and
create staff.

The slug is permanent — it is printed into every table QR code, and the schema
refuses to change it later.

**To add a second restaurant**, run `provision_restaurant` again with a
different slug. One project holds as many as you like; staff and orders are
scoped to their own by row level security, not by the app remembering to
filter.

## 5. Point the app at it

**Project Settings → API** gives you the URL and the key (labelled
*Publishable key* on new projects, *anon public* on older ones — either works).

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

That is *one* app for every restaurant on the project. The first time it opens
it asks which restaurant this device is for, and takes the merchant ID —
`EZ-4K7Q2M`, on the owner's **Staff** screen — either typed in or scanned off
the QR code there. It remembers, so a kitchen tablet is asked once, on the day
it arrives.

Add `--dart-define=RESTAURANT_SLUG=demo` to lock a build to one restaurant
instead. That is the right answer when a single shop has its own app in its own
store listing: nothing asks, and nothing can be re-pointed by somebody holding
the tablet.

The sign-in screen tells you which mode you got: demo logins if it fell back to
the device, **This device is set up for …** if it reached your project.

That key is designed to ship inside client apps and grants nothing on its own,
because every table has row level security. The key that must **never** appear
in a build, a repository or a screenshot is the `service_role` key.

## 6. Fill in the restaurant

Sign in as the owner. There is no menu yet — a fresh restaurant is genuinely
empty, unlike the demo. Add categories, dishes and tables through **More**, and
print the QR codes from **Tables & QR**.

Then add staff through **More → Staff**. Kitchen and cashier accounts get a
6-digit PIN and appear on the PIN pad; admins get a username and password.

---

## How it hangs together

**Nothing writes to an order directly.** There is no INSERT or UPDATE policy on
`orders` at all — the absence is deliberate. Every mutation goes through a
`SECURITY DEFINER` function that checks the caller's role and the order's
current state first. So the rules the app is built on live in one place:

| Rule | Function |
| --- | --- |
| Kitchen owns NEW → COOKING → READY | `start_cooking`, `mark_ready` |
| Cashier owns READY → PAID → COMPLETED | `collect_payment`, `complete_order` |
| Cancel only while queued | `cancel_order` |
| Edit items only while queued | `set_order_item_quantity` |
| Order numbers unique per restaurant | `next_order_number` |
| Prices come from the menu, not the client | `place_order` |

That last one matters more than it looks. `place_order` takes only the dish and
the quantity; it reads the price out of `menu_items` itself. A patched client
cannot order a $12 dish for one cent.

**Staff never type an email address.** They are real Supabase Auth users, but
the app derives the address from what they do type:

```
admin            <username>@<slug>.staff.ezorder.app
kitchen/cashier  <staff-id>@<slug>.staff.ezorder.app
```

Both are derivable with no lookup — which means there is no "does this username
exist" endpoint for anyone to probe.

**Menus are world-readable; orders are not.** A diner scans a sticker and has to
read the menu before they are anyone at all, so `restaurants`, `categories`,
`menu_items` and `restaurant_tables` allow public SELECT. Orders are readable
only by that restaurant's staff and by the diner who placed them.

---

## Things worth knowing before you go live

**A 6-digit PIN is now an internet-facing password.** On the device-only demo a
PIN was protected by physical access to the phone. Against a real auth endpoint
it is six digits. Supabase rate-limits login attempts, which helps, but if
these tills are reachable from outside the restaurant consider raising
`StaffAccount.pinLength` in `lib/models/staff_account.dart` — the pad submits on
the last digit, so it adapts on its own.

**The staff directory is public.** The PIN pad has to list names to tap before
anyone is signed in, so `staff_directory()` is granted to `anon`. It exposes
first names and roles for a restaurant whose slug you already know — no contact
details, no secrets. If even that is too much for your setting, revoke the
`anon` grant and have staff sign in by typing their username instead.

**Photos are base64 in a column.** Fine for a few dozen dishes; if you get to
hundreds, move them to Supabase Storage and keep a URL instead. The client
already caps uploads at roughly 700 KB.

**Realtime refetches rather than patching.** Any change to an order re-reads
that restaurant's orders. At a restaurant's volume — a few rows a minute — that
is cheaper than reconstructing state from row deltas and getting it subtly
wrong. If you ever run this at a scale where it matters, that is the place to
look.

**`provision_restaurant` and `create_auth_user` are not callable from the app.**
Both are revoked from `anon` and `authenticated`; they exist for the SQL editor.
Staff creation from inside the app goes through `create_staff_account`, which
checks that the caller is an admin of that restaurant first.
