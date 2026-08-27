-- ============================================================================
--  EZ Order — hardening
-- ============================================================================
--
--  Run after 0001–0006. Safe to re-run.
-- ============================================================================

-- --------------------------------------------------- the order counter leak
--
-- `restaurants` is world-readable, which it has to be: a diner scans a sticker
-- and needs the name, logo and currency before they are anyone. But `select *`
-- also handed out `next_order_number`, and that is a business metric — anyone
-- could poll it and watch how many orders a restaurant takes in a day, for
-- every restaurant in the project.
--
-- Column grants fix it without touching the policy. The client now names the
-- columns it wants, and next_order_number is not among them.
-- next_order_number() is SECURITY DEFINER, so it is unaffected.

revoke select on public.restaurants from anon, authenticated;
grant select (
  id, slug, name, name_km, logo, phone, address,
  currency_symbol, currency_code, payment_methods, plan, created_at
) on public.restaurants to anon, authenticated;

-- ============================================================================
--  Still open, and deliberately not "fixed" here because the fix is a product
--  decision rather than a line of SQL:
--
--  1. THE CUSTOMER LIST IS PUBLIC. `restaurants` has `using (true)`, so anyone
--     with the anon key can list every restaurant on this project. That is
--     fine while it is your own restaurants; it is not fine once you are
--     selling to competitors of each other. The fix is to stop selecting the
--     table directly and go through a SECURITY DEFINER function that takes a
--     slug and returns exactly one row.
--
--  2. STAFF PINS ARE BRUTE-FORCEABLE IN PRINCIPLE. staff_directory() is public
--     — the PIN pad has to list names before anyone is signed in — and it
--     returns the staff id, from which the login address is derived by a rule
--     both the app and 0004 know. So an attacker knows a valid username and
--     needs only six digits: a million combinations, and no account lockout.
--     Supabase rate-limits auth per IP, which makes this slow rather than
--     impossible.
--
--     The honest fixes, in order of effort:
--       * raise StaffAccount.pinLength to 8 (one line, but every existing PIN
--         must be re-issued),
--       * lock an account for a few minutes after a run of failures,
--       * stop returning the staff id publicly and have the pad exchange an
--         opaque token instead.
-- ============================================================================
