# EZ Order — Flutter QR ordering prototype

A mobile-first prototype of a QR ordering SaaS for small restaurants and food
courts. One app contains all four sides of the workflow, and a demo role
switcher pinned to the top lets an evaluator follow a single order end to end:

```
Customer scans table QR → orders → Kitchen cooks → Cashier takes payment → Customer sees Paid
```

Built with Flutter (iOS and Web; Android is one `flutter create` away) instead
of the React stack named in
the brief. Everything else follows the specification, plus the extras listed in
section 5.

The whole interface runs in **English or Khmer**, switchable from the bar at
the top of every screen.

---

## 1. Configure it

Everything you would normally want to change — the restaurant's name and
contact details, the currency, the colours, the corner radii, the demo staff
logins, how many tables exist — lives in one file:

```
lib/config/app_config.dart
```

It has three sections:

| Section | What it holds |
| --- | --- |
| `Brand` | Name (English + Khmer), logo, phone, address, currency, payment methods, the QR slug |
| `Palette` | The accent colour, the neutral ramp, the order-status colours |
| `Style` | Corner radii, the font family, how far the app follows the phone's text-size setting |
| `Seed` | Table count and the demo staff logins — first-run only |

Change a value, save, and press `r` in the terminal running `flutter run`.
Colours and sizes appear immediately.

To rebrand the app you normally only touch the three `Palette.accent*` values.
The accent is reserved for things you can tap — prices and body text stay
near-black on purpose, so the only accent on a menu screen is a control.

`Seed` values only apply to a **fresh install**, because the app mirrors its
state into the device's local storage after every change and restores it on the
next launch. To pick up a change there, use **Admin → Settings → Reset demo
data**, or delete and reinstall the app.

Two things live outside that file, because iOS owns them:

- the name under the home-screen icon — `CFBundleDisplayName` in
  `ios/Runner/Info.plist`
- your Apple signing details — `ios/Flutter/Signing.xcconfig`, covered below

---

## 2. Run it on your iPhone

The project builds through **Swift Package Manager**. There is no `Podfile` and
CocoaPods is not required — nothing to `pod install`.

### Once, to set up signing

Apple will not install an app on a physical device unless it is signed. A
**free Apple ID is enough** for your own phone; the app stops opening after
seven days and you re-run `flutter run` to refresh it. A paid Apple Developer
account ($99/yr) removes the expiry.

1. **Add your Apple ID to Xcode** — Xcode → Settings → Accounts → **+** → Apple
   ID → sign in.
2. **Copy your Team ID** — it is the 10-character code beside your name in that
   same window, under *Team* (something like `A1B2C3D4E5`).
3. **Paste it into `ios/Flutter/Signing.xcconfig`**:

   ```
   APP_DEVELOPMENT_TEAM = A1B2C3D4E5
   APP_BUNDLE_ID = com.yourname.restaurantqr
   ```

   The bundle identifier must be globally unique — a domain you control,
   reversed, or just your own name. Free Apple IDs sometimes reject an
   identifier someone else has claimed; if the build complains, make it more
   unusual and run again.

4. **Install the iOS platform component** if Xcode has not already — Xcode →
   Settings → Components → **iOS**, or from the terminal:

   ```bash
   xcodebuild -downloadPlatform iOS
   ```

   Having the iOS *SDK* is not the same as having the platform installed; a
   build that fails with *"iOS … is not installed"* means this step.

### Every time

```bash
cd restaurant_qr_ordering
flutter pub get
flutter devices          # find your phone's name
flutter run -d "<your phone>"
```

The first install, iOS refuses to open an app from an unknown developer.
Approve it once on the phone at **Settings → General → VPN & Device Management
→ your Apple ID → Trust**, then launch the app again.

Camera and photo-library permission strings are already in
`ios/Runner/Info.plist`, so the QR scanner and dish-photo upload both work on
device.

### On the desktop, for a faster loop

```bash
flutter run -d chrome --web-hostname 0.0.0.0 --web-port 8080
```

`--web-hostname 0.0.0.0` matters if you want to scan a table QR with a real
phone. The codes encode whatever address the browser is using, so open the app
on your machine's LAN address (`http://192.168.x.x:8080`, not `localhost`) —
then the QR a phone camera reads points somewhere the phone can actually reach.
On `localhost` the codes are only scannable by the same machine.

### Checks

```bash
flutter test        # 76 tests: business rules, plus widget tests that render
                    # every role in both languages and catch layout breakage
flutter analyze     # clean
```

Built and verified against Flutter 3.47.1 / Dart 3.13.1, Xcode 26.6.

---

## 3. The 60-second demo

1. **Customer** — tap *Table 05* on the entry screen (or use the camera
   scanner, or *Order takeaway* for no table at all). The menu opens with the
   table already attached.
2. Tap **Chicken Fried Rice**, set quantity to 2, type `No onion, please`,
   **Add to Cart**.
3. Open the **Cart** tab, add an order note, **Submit Order**. An order number
   is issued and the confirmation screen appears. Tap **Track Order**.
4. Tap **Staff sign in**, choose *Sophal*, key in **110011** — the new ticket is
   waiting, note and all. Tap **Start Cooking**, then **Ready to Serve**.
5. Switch to **Customer view** in the top bar — the tracker has already moved.
   Nothing was refreshed.
6. Sign out, sign in as *Bopha* with **220022** — the order is under
   *Ready for Payment*. Pick a
   payment method, **Collect Payment**, confirm. The invoice opens; **Print
   Invoice** produces a real 80mm receipt PDF. **Done** closes the table.
7. Back in **Customer view** the order shows **Paid**.

Sign in as the owner (**admin / admin1234**) and you get all three workspaces
on the tabs plus **Manage**. Admin covers the rest: today's figures, every order, menu and category
management (toggle a dish to Sold Out and watch the customer menu block it),
tables with printable QR codes, and restaurant settings.

Admin → Settings → **Reset demo data** puts everything back.

---

## 4. Accounts and access

Staff sign in; customers never do.

| Role | Sign-in | Can do |
| --- | --- | --- |
| Customer | none — scan a QR or tap Takeaway | browse, order, watch the tracker |
| Kitchen | tap name → PIN | New and Ready boards only |
| Cashier | tap name → PIN | watch every live order, take an order at the counter, edit or cancel a queued one, take payment, invoices |
| Admin | username + password | everything, including staff accounts |

Demo accounts, also printed on the sign-in screen:

```
Owner     admin / admin1234
Kitchen   Sophal · PIN 110011
Cashier   Bopha  · PIN 220022
```

Staff PINs are exactly six digits, and the pad signs in on the sixth — there is
no confirm tap. Hashing is deliberately slow, so sign-in is async and the pad
shows a brief *Checking…* rather than freezing a frame.

On the device backend, PINs and passwords are stored as iterated HMAC-SHA256
over a per-account salt, never in the clear, and compared in constant time.
That is the right shape but not a substitute for a server: anything on the
device can be edited by someone with access to the device — which is precisely
why section 5 exists. Connected to Supabase the secrets are Auth's, and this
device never sees them at all.

**Permissions are enforced below the UI, not just in it.** Hiding a button is
never the thing keeping a cashier out of the menu editor. On the device backend
every staff mutation runs through a `_require` guard; connected to Supabase the
same refusals come from Postgres, where a patched client cannot reach them — `test/app_store_test.dart` asserts
that a cashier cannot cook, a kitchen account cannot take money, neither can
touch the menu, and a signed-out visitor can still order as a customer. The
last active admin cannot be deleted or disabled, because with no server there
would be no way back in.

## 5. Where the data lives

Out of the box everything is on the device: a seeded demo restaurant in
SharedPreferences. That is what the test suite runs against, and what you get
with no configuration at all.

Point it at a Supabase project and it becomes a product instead — one database
behind every device, so the kitchen tablet, the till and the diner's phone are
three views of one restaurant rather than three unrelated apps. One project
holds many restaurants; each build says which one it serves.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
  --dart-define=RESTAURANT_SLUG=demo
```

**`supabase/README.md` is the setup guide** — create the project, run four
migrations, enable anonymous sign-in, provision your restaurant. Ten minutes.

The seam is `lib/data/backend/`: an abstract `Backend` with two
implementations, `LocalBackend` (the device) and `SupabaseBackend` (Postgres).
`AppStore` keeps the split that makes this work — the *restaurant* (menu,
tables, orders, staff) belongs to the backend and may change under you at any
moment; the *session* (which table this phone scanned, what is in this cart,
which language) belongs to the device and never leaves it.

Two things change when you connect:

**The rules become the database's.** Every mutation is a `SECURITY DEFINER`
function that checks the caller's role and the order's state in SQL first.
There is no INSERT or UPDATE policy on `orders` at all. A patched build of this
app cannot talk its way past Rule 6, Rule 7, or cancel-only-while-queued — and
`place_order` reads prices from the menu rather than trusting the client, so it
cannot invent a cheap dish either.

**Somebody else is writing too.** Realtime keeps every device on the same
orders. The live sync that used to work only because everything was one phone
now works across the room.

The sign-in screen says which mode you are in: demo logins, or
**Connected · &lt;slug&gt;**.

---

## 6. Beyond the original brief

**Khmer / English — including the menu itself.** The language control sits
beside the role tabs, reachable from every screen in every role, and the choice
is remembered. Interface text lives in `lib/l10n/app_text.dart` as typed
getters, so a missing translation is a compile error rather than a blank label.

The menu is bilingual content, not just bilingual chrome: the admin enters an
English and a Khmer name and description for every dish, a Khmer name for every
category, and a Khmer restaurant name, and the customer's language switch swaps
all of it at once. Blank Khmer falls back to the English text, and Admin → Menu
reports how many dishes still need Khmer, flagging each one in the list. The
Khmer name travels onto the order, so kitchen tickets and printed receipts stay
in the right language too — the bundled Noto Sans Khmer is registered as a font
fallback in the app theme and in both PDFs. The demo menu ships fully
translated.

**Photo upload.** Admin → Menu → a dish → *Upload photo* or *Take photo*.
Images are downscaled to 1000px at 78% quality before being stored with the
dish, and anything still over ~700 KB is refused rather than silently blowing
the browser's storage quota. The bundled illustrations remain as a fallback,
and *Remove photo* returns to them.

**Discounts.** A dish has a full price plus an optional discount percentage
(0–90). The editor previews what the customer will actually pay. The menu shows
the new price with the old one struck through and a `-20%` flash on the photo.
The discounted price is what enters the cart, the order and the receipt — and
because the charged price is copied onto the order line, changing a discount
later never rewrites an order that has already been placed.

**Dine in or takeaway.** Dine-in is the default and behaves exactly as before.
A customer with no table taps *Order takeaway* on the entry screen. The choice
also sits as a segmented control directly under the restaurant name on the
menu, so someone who has just scanned a table QR can switch to takeaway in one
tap, and it can still be changed in the cart before submitting. Picking dine-in
without a table opens a table picker rather than throwing the customer back to
the QR screen — the basket survives, because the only thing missing was the
table number. A takeaway order carries no table at all:
kitchen tickets and receipts show a black **TAKEAWAY** badge in its place and
staff call the order number, and takeaway never marks a table occupied. Rule 11
is amended accordingly: an order carries either a table or the takeaway marker.

**The cashier as a front desk.** The till has three tabs. **Live** is every
order in the restaurant right now, whoever placed it and whatever state it is
in, so the cashier can answer "where is table 7's food?" without walking to the
kitchen. **To pay** is the Rule 7 queue. **Closed** is the day's history —
paid, completed and cancelled.

**Taking an order for a customer.** *New order* on the till opens a counter
version of the menu: pick takeaway or a table, tap dishes to build a basket,
review quantities and add a note, then *Send to kitchen*. It lands in NEW like
any other order and shares the one order-number sequence, so the kitchen board
and the customer tracker treat it identically; only `Order.placedBy` records
that it came from the counter. The basket is held by the screen, never in
`AppStore.cart`, so a cashier keying in a phone order cannot disturb the
customer session the same device may also be showing.

**Editing an order.** *Edit items* on a live ticket opens the order line by
line: change a quantity with the stepper, or take a dish off outright. Removing
the last remaining line is refused — an order with nothing on it is not
something the kitchen or the till can act on, so that case is a cancellation and
has to be made as one. Edits go straight through `AppStore`, so the kitchen
ticket, the totals and the customer's tracker all move with them; there is no
draft to save. Same window as cancelling: only while the order is still queued.

**Cancelling an order.** A cashier can pull an order back for a customer, but
only while it is still queued: once the kitchen taps *Start Cooking* the food is
being made, and the button is gone. The rule is enforced in `AppStore`, not just
on the button, so a stale screen cannot cancel something the kitchen picked up a
second ago — the attempt fails with a message instead. A cancelled order frees
its table, drops out of the live board and the day's takings, and shows the
customer a plain "This order was cancelled" in place of the progress ladder.

**Signature dishes.** A separate star flag from *Popular*: Popular controls the
first tab of the menu, Signature marks a house special with a star badge on the
card and in the dish sheet.

**Running cart summary.** Adding a dish slides a summary bar up over the menu
showing the item count and the running total; it pops each time the count
changes so a second tap is never silent, and tapping it opens the full order.
The cart itself opens on an *Order summary* header, every line can have its
quantity changed or be removed outright, and the totals card breaks out items,
subtotal and total — all before *Submit Order* is available.

**Kitchen counts.** A strip across the top of the board shows what is queued,
what is on the stove, what is waiting to go out, and the day's tally — orders
cooked today and the number of dishes that came to. The header adds the total
dish count still to cook, so a cook can see the workload rather than just the
ticket count.

**Two-tab kitchen.** New and Ready. A ticket stays in **New** for its whole
working life — *Start Cooking* flips it to *In Progress* in place and swaps the
button to *Ready to Serve*; only that second tap moves it across to **Ready**.
Rule 6 is unchanged underneath: NEW → COOKING → READY, no step skipped.

---

## 7. How it is put together

```
lib/
├── config/app_config.dart     ★ the one file to edit: brand, palette,
│                              shape, seed data
├── main.dart                  loads the store, then runs the app
├── app.dart                   MaterialApp, QR deep links, role shell
├── l10n/                      English + Khmer string table, status labels
├── auth/                      salted, iterated PIN and password hashing
├── models/                    MenuItem, MenuCategory, RestaurantTable,
│                              Order + OrderItem, CartLine, StaffAccount,
│                              RestaurantSettings
├── data/
│   ├── demo_data.dart         ABC Restaurant seed: menu, 10 tables, 12 orders
│   └── app_store.dart         the single source of truth (ChangeNotifier)
├── data/backend/              where the restaurant's data lives
│   ├── backend.dart           the seam: one interface, two implementations
│   ├── local_backend.dart     on this device — the demo, and what tests run
│   └── supabase_backend.dart  Postgres, RLS, RPCs and realtime
├── theme/app_theme.dart       palette, status colours, control styling
├── widgets/                   shared chrome, order ticket, tracker, stepper,
│                              photo picker…
└── screens/
    ├── auth/                  staff sign-in and PIN pad
    ├── customer/              QR entry, scanner, menu, detail, cart,
    │                          confirmation, tracker
    ├── kitchen/               New (incl. In Progress) / Ready
    ├── cashier/               Ready for Payment / Completed, invoice
    └── admin/                 dashboard, orders, manage (menu, tables,
                               staff, settings)
```

**One store, four roles.** `AppStore` holds the menu, tables, settings, the
cart and every order. All four role screens read and write the same instance
through `provider`, which is why the customer's tracker moves the moment the
kitchen taps a button — no polling, no refresh. The whole state is mirrored
into `SharedPreferences` after each change, so a reload resumes the demo where
it left off.

**Deep links.** `/order/demo/table/05` (and `/restaurant/demo/table/05`) open
the menu for that table directly. The in-app scanner also accepts the raw
identifier `restaurant-demo-table-05`, so the codes work on mobile builds where
there is no web origin to point at.

**Boundary that matters:** there is no backend. Accounts, menu and orders all
live in this device's local storage. Sign-in, roles and permissions are real
and enforced, but a kitchen tablet and a cashier phone would each hold their
own separate data — they would not see each other's orders. Making this work
across devices needs a server; nothing else here has to change.

---

## 8. Where each business rule lives

| Rule | Enforced in |
| --- | --- |
| 1 — no customer account | no auth anywhere; scanning a table is the whole session |
| 2 — unique QR per table | `AppStore.addTable`, `RestaurantTable.qrId` |
| 3 — the QR identifies the table | `AppStore.resolveScannedValue`, `TableEntryPage` |
| 4 — order from the phone | mobile-first customer screens |
| 5 — notes on items and orders | `FoodDetailSheet`, `CartScreen`, carried into `Order` |
| 6 — kitchen: NEW → COOKING → READY | `startCooking` / `markReady`, guarded by `_transition`; both live in the New tab |
| 7 — cashier: READY → PAID → COMPLETED | `collectPayment` / `completeOrder` |
| 8 — no edits after submit | the cart is cleared on submit; tracking is read-only |
| — cancel only before cooking | `AppStore.cancelOrder`, gated on `OrderStatus.isCancellable` |
| — edit items only before cooking | `AppStore.setOrderItemQuantity`, same gate; refuses to empty an order |
| — a counter order is an ordinary order | `AppStore.placeStaffOrder`; same NEW state, same number sequence, `placedBy` records the till |
| 9 — sold out cannot be ordered | `AppStore.addToCart` throws; the menu disables Add |
| — discounted price is what is charged | `MenuItem.effectivePrice`, copied onto the order line |
| 10 — configurable payment methods | Admin → Settings → Payment methods |
| 11 — every order is placed somewhere | `submitOrder` refuses a dine-in order with no table; switching to dine-in asks for one via `chooseTable`; takeaway carries the marker instead |
| — staff permissions | `AppStore._require`, checked on every staff mutation |
| 12 — every order has a unique number | `_nextOrderNumber`, covered by tests |

`test/app_store_test.dart` asserts all of these.

---

## 9. Design system

Type is **Kantumruy Pro** — one Google font, bundled as a single 200 KB
variable file, drawn for Khmer and Latin together. A Khmer dish name and an
English one share the same voice instead of switching typeface mid-sentence,
which is what a Latin font plus a Khmer fallback does. It replaced Inter plus
Noto Sans Khmer and cut the bundled fonts from 1.2 MB to 200 KB.

Text is sized for a busy room rather than a design tool: body text is 15px,
secondary labels 14px, nothing below 12px, and the secondary greys were
darkened for contrast. The app also honours the reader's own text-size setting,
clamped to 1.3x — enough to help someone who has turned text up, not so much
that a kitchen ticket stops fitting its card. `test/app_flow_test.dart` renders
every workspace at that maximum in both languages and fails on any overflow. Colour is one warm accent
reserved for interactive things — buttons, the selected tab, the cart bar —
against a cool neutral ramp; prices are near-black rather than orange, so the
only orange on a menu screen is something you can tap. Cards are white with a
hairline border and a two-step shadow. Radii, type sizes and shadows are tokens
in `lib/config/app_config.dart` and surfaced to the app through
`lib/theme/app_theme.dart`; nothing should hard-code them.

`test/design/` renders the main screens to PNGs in `test/design/shots/` so the
design can be reviewed without a browser:

```bash
DESIGN_SHOTS=1 flutter test --update-goldens test/design
```

They are review images, not pixel assertions, and are skipped by a normal
`flutter test`.

## 10. Notes on the artwork

Dish images are generated flat-vector illustrations in `assets/food/`, produced
by `tool/generate_food_images.py` (Pillow). They are bundled, so the app needs
no network at runtime, and they are what a dish falls back to when no photo has
been uploaded. Drop your own PNGs into `assets/food/` and add their keys to
`DemoData.imageChoices` to extend the built-in set.

The demo dishes ship with English names only. Add a Khmer name to any dish in
the editor to see the Khmer menu fill in — the field is right under the English
one.

## 11. Deliberately not built

Inventory, payroll, accounting, loyalty, delivery, reservations, advanced
analytics and payment gateways — all out of scope per the brief.

Two things that *were* out of scope have since been built, and the brief's line
about them no longer holds: **real authentication** (staff are Supabase Auth
users, with roles enforced by row level security) and **multi-branch** (one
Supabase project holds many restaurants, each with its own slug, staff and
orders). See section 5.

Payments are still recorded, not taken: the cashier picks a method and the
order moves to PAID. Nothing talks to Bakong, a card terminal or KHQR.
