# Supabase edge functions — deploy guide

This project has two edge functions in `supabase/functions/`:

- **`fetch-url`** — CORS proxy so **URL recipe import works on the web build**
  (browsers can't fetch arbitrary cross-origin pages; native fetches directly).
  Deploy it public:
  ```bash
  supabase functions deploy fetch-url --no-verify-jwt
  ```
  No SQL, no secrets. It's a generic GET passthrough; if you want to limit abuse,
  tighten `Access-Control-Allow-Origin` in `index.ts` to `https://squirion.github.io`.

- **`gc-images`** — image garbage collection (below).

---

# Image garbage collection — deploy guide

Orphaned image blobs (no `recipe_images` ref and not used as an avatar) are
cleaned up by the `gc-images` Edge Function, on a daily schedule, with a 7-day
tombstone grace period so offline stealers can still re-register/re-upload.

This is a **cost optimization** — not required for correctness. At small scale
you can skip it; orphaned blobs are harmless until storage adds up.

## 1. One-time SQL (Supabase → SQL Editor)

```sql
-- tombstone marker: when an image first became orphaned
alter table images add column if not exists orphaned_at timestamptz;

-- mark newly-orphaned images / clear ones that got re-referenced
create or replace function gc_sweep_orphans() returns void
language sql security definer set search_path = public as $$
  update images i set orphaned_at = now()
   where orphaned_at is null
     and not exists (select 1 from recipe_images ri where ri.image_hash = i.hash)
     and not exists (select 1 from profiles p     where p.avatar_hash = i.hash);
  update images i set orphaned_at = null
   where orphaned_at is not null
     and (exists (select 1 from recipe_images ri where ri.image_hash = i.hash)
          or exists (select 1 from profiles p   where p.avatar_hash = i.hash));
$$;
revoke all on function gc_sweep_orphans() from public, anon, authenticated; -- service-role only
```

## 2. Deploy the function

```bash
supabase login
supabase link --project-ref ubzjhklkpxcbrghfmjdd
supabase functions deploy gc-images --no-verify-jwt
```

(`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically in the
Edge Function runtime — no secrets to set.)

## 3. Schedule it daily

Option A — Supabase dashboard: **Edge Functions → gc-images → Schedules → add cron** `0 3 * * *`.

Option B — pg_cron + pg_net (SQL Editor):

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.schedule('gc-images-daily', '0 3 * * *', $$
  select net.http_post(
    url := 'https://ubzjhklkpxcbrghfmjdd.functions.supabase.co/gc-images',
    headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key', true))
  );
$$);
```

## Test manually

```bash
curl -X POST https://ubzjhklkpxcbrghfmjdd.functions.supabase.co/gc-images \
  -H "Authorization: Bearer <SERVICE_ROLE_KEY>"
# → {"ok":true,"deleted":N}
```

Newly-orphaned images won't be deleted until they've been orphaned ≥7 days
(tombstone grace). To verify immediately, temporarily lower `GRACE_DAYS` in
`index.ts` and redeploy.
