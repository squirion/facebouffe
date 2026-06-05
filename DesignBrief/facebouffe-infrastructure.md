# Facebouffe — Infrastructure & operations reference

A "future-me" map of every external piece the project depends on, what each does,
where its config lives, and how to operate it. Schema/feature details live in the
other briefs; this is the **ops** layer.

## Mental model
A **local-first** Flutter app (Android + web PWA). It works fully offline with no
account. An **optional** cloud layer (sign-in) adds multi-device sync + the social
features. Two build targets ship from one codebase: a **web PWA** and a **signed
Android APK**.

---

## 1. Source & CI/CD — GitHub
- **Repo:** `squirion/facebouffe`, default/production branch **`main`**.
- **Workflow:** `.github/workflows/release.yml` (single file, three jobs). Flutter
  pinned to **3.44.1**.
- **Triggers:**
  | You do… | CI does… |
  |---|---|
  | **push to `main`** | builds the web PWA → deploys to **GitHub Pages** |
  | **push a tag `vX.Y.Z`** | builds a **signed APK** → publishes a **GitHub Release** (+ release notes) |
  | manual "Run workflow" | re-deploys web |
- **APK signing:** the release keystore is restored in CI from repo **Actions
  secrets** — `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS` (written to `android/key.properties` at build time; the
  `.jks` is never committed). **Keep a backup of the keystore + passwords** — lose
  them and you can't ship updates to existing installs.

## 2. Web hosting — GitHub Pages
- **URL:** https://squirion.github.io/facebouffe (built with `--base-href /facebouffe/`).
- Served from the Pages artifact the `web` job uploads. No separate host/DNS.

## 3. In-app updater
- The web job writes **`version.json`** (Flutter's fields + our `build` and `apk`
  URL) to the Pages site. The app (`UpdateCheck`) fetches it and, if a newer build
  exists, offers **Download APK** (Android, from the latest Release) or **Refresh**
  (web). Latest APK is always at
  `…/releases/latest/download/facebouffe.apk`.

---

## 4. Backend — Supabase
- **Project:** ref **`ubzjhklkpxcbrghfmjdd`**, region **us-east-1**, **Free** tier.
  Dashboard: https://supabase.com/dashboard/project/ubzjhklkpxcbrghfmjdd
- **What it provides:**
  - **Postgres** — all cloud data (recipes, profiles, friendships, comments,
    linked_recipes, overlays, user_library, images registry). Schema + RLS are
    authoritative in `facebouffe-social-layer.md` §2/§3.
  - **Auth** — passwordless **email OTP** (6-digit code).
  - **Storage** — private bucket **`recipe-images`** holding content-addressed
    image blobs (object key = sha-256 hash).
  - **Edge Functions** — see §6.
  - **pg_cron + pg_net** extensions — schedule the GC function.
- **Keys (important):**
  - **Publishable key** — client-side, **public by design**, committed in
    `lib/config/supabase_config.dart`. RLS is what protects data, not this key.
  - **Secret / service-role key** — server-only; **never in the app**. Auto-injected
    into Edge Functions as `SUPABASE_SERVICE_ROLE_KEY`.
- **RLS is on for every table.** Adding a table = enable RLS + add policies, or it's
  deny-all. New tables/columns are applied by **running SQL in the dashboard SQL
  Editor** (there's no migration tooling wired up — SQL is the source of truth,
  mirrored in the brief).

## 5. Email / OTP delivery — Brevo (SMTP)
- Supabase's built-in mailer is throttled (~2–3/hr, testing only), so Auth uses
  **custom SMTP via Brevo** (free tier **300 emails/day**). Configured in
  Supabase → Authentication → Emails → SMTP.
- Sender: `squirion27@gmail.com`. The **Confirm signup** + **Magic Link** email
  templates must use **`{{ .Token }}`** (the 6-digit code), not the confirmation
  link — the app verifies a code, not a link.
- Brevo dashboard: https://app.brevo.com (SMTP key under SMTP & API).

## 6. Edge Functions (`supabase/functions/`)
Both deploy from the **Supabase dashboard** (Edge Functions → Deploy via Editor →
paste code), or `supabase functions deploy <name>` if you install the CLI. Guide:
`supabase/README-gc.md`.
- **`fetch-url`** — CORS proxy so **URL recipe import works on the web build**
  (browsers can't fetch arbitrary cross-origin pages; native fetches directly).
  Deployed **public** (Verify JWT OFF). No SQL, no secrets.
- **`gc-images`** — daily **image garbage collection**: tombstones orphaned blobs
  (no `recipe_images` ref AND not an avatar) via `images.orphaned_at`, hard-deletes
  past a 7-day grace. Needs its SQL (`orphaned_at` column + `gc_sweep_orphans()`)
  and a **cron** schedule (`0 3 * * *`) created in the dashboard Cron UI. Optional
  housekeeping — nothing breaks without it.

## 7. Image storage today, and the eventual Cloudflare R2 migration
- **Today:** images live in the Supabase **Storage** bucket `recipe-images`,
  content-addressed + ref-counted (`images` / `recipe_images` tables).
- **Why R2 later:** at scale, object storage egress/storage is cheaper on
  **Cloudflare R2** (no egress fees). It's **deferred** — current scale doesn't
  need it.
- **What's already future-proofed:** the `images.r2_key` column exists (currently
  = the storage object key / hash) and all blob access goes through `SyncBackend`,
  so a migration means: stand up an R2 bucket, copy blobs, point upload/download
  (and signed-URL minting) at R2 in the Supabase backend impl, backfill `r2_key`.
  No schema redesign.

---

## 8. Secrets — where each lives
| Secret | Lives in | Used for |
|---|---|---|
| Android keystore (+ passwords, alias) | GitHub **Actions secrets** | signing the release APK |
| Supabase **service-role** key | Supabase Edge Function runtime (auto) | GC function (server-only) |
| Brevo **SMTP key** | Supabase Auth → SMTP settings | sending OTP emails |
| Supabase **publishable** key | `lib/config/supabase_config.dart` (repo) | client API (public by design) |

## 9. Config / file map (in the repo)
- `lib/config/supabase_config.dart` — Supabase URL + publishable key (overridable via `--dart-define`).
- `supabase/functions/{fetch-url,gc-images}/` + `supabase/README-gc.md` — edge functions + deploy guide.
- `.github/workflows/release.yml` — the entire CI/CD.
- `android/key.properties` (CI-generated, git-ignored) — signing config.
- `DesignBrief/` — `facebouffe-design-brief.md` (app), `facebouffe-social-layer.md`
  (cloud schema/RLS/§), `facebouffe-social-implementation-plan.md` (phases), this file.

## 10. Routine ops — "how do I…?"
- **Ship a web update:** push to `main`.
- **Cut an app release:** bump `version:` in `pubspec.yaml`, commit, then
  `git tag -a vX.Y.Z -m "…" && git push origin vX.Y.Z` → CI builds + publishes the APK.
- **Add a cloud table/column:** write the SQL (mirror it in the brief) → run it in
  the Supabase **SQL Editor** → enable RLS + policies.
- **Change/redeploy an edge function:** edit `supabase/functions/<name>/index.ts`,
  redeploy via the dashboard editor (or CLI).
- **Rotate the publishable key:** edit `supabase_config.dart`, push.
- **Test on the phone:** wireless adb (drops often) → `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

## 11. Free-tier limits to watch
- **Supabase Free:** DB size, storage, monthly active users, edge-function
  invocations — fine at personal scale; watch storage growth (→ GC, → R2).
- **Brevo Free:** 300 emails/day (= sign-ins).
- **GitHub:** Actions minutes + Pages — free for public repos at this volume.
