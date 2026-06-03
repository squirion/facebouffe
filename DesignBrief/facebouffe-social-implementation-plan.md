# Facebouffe — Social Layer: Implementation Plan

> Companion to `facebouffe-social-layer.md` (architecture + UI) and the MockUp (`fb-social.jsx`). Breaks the build into ordered, independently-testable phases. **Invariant across every phase: logged-out users see today's app, unchanged** — social is strictly additive behind optional login.

---

## A. Prerequisites — accounts, keys, and what to know

### Recommendation: start **Supabase-only**, defer Cloudflare R2
The architecture names R2 for cheap image hosting at scale, but for the **limited release you can use Supabase Storage** (S3-compatible, integrated auth/RLS/signed URLs, generous free tier) and add **zero server code**. That's one service instead of two and no edge functions to write — much simpler to start. The `SyncBackend` boundary + content-addressed images make swapping to R2 later a contained change. **So: set up Supabase now; create R2 only when storage/egress actually demands it (Phase 7).**

### Supabase setup (you'll do this once)
1. Sign up at **supabase.com** (free; GitHub or email).
2. **New project** → name it, set a **database password** (save it in a password manager — it's the Postgres admin password; rarely needed but keep it), pick a **region** near you, free plan.
3. After it provisions, open **Project Settings → API Keys** and copy (use the **new** keys; the legacy `anon`/`service_role` JWTs are deprecated):
   - **Project URL** — e.g. `https://abcd1234.supabase.co`
   - **Publishable key** (`sb_publishable_…`, = the old *anon* key) — **safe to ship in the app** (client key; *Row-Level Security* protects the data). Pass it as the `anonKey` in `Supabase.initialize` (use a current `supabase_flutter`).
   - **Secret key** (`sb_secret_…`, = the old *service_role* key) — **secret. NEVER put this in the app.** Bypasses RLS; admin/CI/edge-function use only. Treat it like a root password. (Bonus over the legacy JWTs: publishable/secret keys are independently **rotatable/revocable**.)
4. **Auth → Providers:** enable **Email**, turn on **magic link** (passwordless). Under **Auth → URL Configuration**, add the app's **redirect URL** (a custom scheme, e.g. `io.facebouffe://login-callback`) so the email link returns to the app. (Free tier sends email via Supabase's shared SMTP with low hourly limits — fine for dev; add your own SMTP before a real launch.)
5. **Schema:** apply the DDL + RLS from the spec. Two ways:
   - Quick start: paste into **SQL Editor** and run.
   - Better: the **Supabase CLI** (`supabase init`, migrations in `supabase/migrations/*.sql`, `supabase db push`) so the schema is **versioned in the repo and portable** — recommended once it stabilizes.
6. **Storage:** create a **private bucket** (e.g. `recipe-images`), add storage RLS policies, serve via **signed URLs**. (Objects will be named by content hash — §5 of the spec.)

**What the app actually needs:** just the **Project URL + publishable key**, passed in via `--dart-define` (don't hard-code; keep them in CI/run config). Add the `supabase_flutter` package. The **secret key** stays off-device.

### Cloudflare R2 (only if/when you adopt it — Phase 7)
1. Cloudflare account (free) → **R2** → it'll ask you to **enable R2 / add billing** even though there's a free tier (10 GB storage, **no egress fees**).
2. Create a **bucket**; create an **R2 API token** → you get an **Access Key ID + Secret Access Key** (S3-compatible) + an account-specific endpoint. **These are secrets — server-side only.**
3. Don't put S3 creds in the app. Instead route uploads / signed-URL minting through a **Supabase Edge Function** (Deno/TS) that holds the R2 secret. (This is the extra complexity you avoid by staying on Supabase Storage for v1.)

### The one security rule that matters
The app ships **only the publishable key**; **RLS is what makes that safe.** Tables are **unprotected until you enable RLS on each one** — so *enable + test RLS before any real data goes in*. All true secrets (the secret key, R2 keys) live server-side, never in the APK.

### Beginner gotchas
- Free Supabase projects **pause after ~1 week idle** — wake from the dashboard.
- Magic-link **email rate limits** on free tier (a handful/hour) — enough for testing.
- Consider a **separate "dev" project** from a future "prod" one (or accept one project for the limited release).
- Your **local-first data is still the real backup**; the cloud is convenience + social.

---

## B. Cross-cutting (applies to all phases)
- **One seam: `SyncBackend`** (spec §6). All Supabase/Storage calls live behind it (one impl now) so the host stays swappable. UI/state never import Supabase directly.
- **Testing needs two accounts** — use two devices/emulators (or two magic-link emails). Most social bugs only show with A↔B.
- **Offline-first:** every phase must degrade cleanly with no network (queue writes, no crashes, social affordances hidden/disabled).
- **Each phase ends with a concrete acceptance test** and is shippable behind the login gate.

---

## C. Phased plan

### Phase 0 — Foundations (no visible feature)
**Goal:** backend exists; app talks to it behind the seam.
- Create the Supabase project (§A). Apply schema + RLS + helper functions + `lookup_username` RPC; **manually verify RLS** with two test users in the SQL editor (A can't read B's private rows, etc.).
- Add `supabase_flutter`; wire init with URL + anon key via `--dart-define`.
- Define the `SyncBackend` interface + a Supabase implementation **skeleton** (methods throw `unimplemented` for now). Add an `online/account` signal to `AppState`.
- Define `CloudRecipe` mapping: `Recipe.toJson` **minus** the private `personal` block, **with images as content hashes**. A helper to extract image hashes from a recipe.
- **Acceptance:** schema deploys; RLS behaves under manual two-user SQL tests; app compiles and connects (a trivial authenticated ping works); nothing user-visible changed.

### Phase 1 — Auth & account (optional login)
**Goal:** sign in, get an identity, sign out. *(Mockup: SignInScreen, UsernameSetupScreen, AccountScreen.)*
- Magic-link sign-in (`signInWithOtp` + `emailRedirectTo`); handle the **deep link** back into the app (Android intent filter for the custom scheme) and `onAuthStateChange`.
- **Username setup** on first sign-in: live uniqueness check via `lookup_username`/insert; permanent handle.
- **Account screen** in Réglages: username/email, sync-status placeholder, **sign-out** (note that local data stays).
- **Acceptance:** sign in via emailed link on a real device; pick a unique username (collision rejected); see Compte; sign out; the logged-out app is identical to today.

### Phase 2 — Personal cloud sync (multi-device, **no social yet**)
**Goal:** your own cookbook backs up and syncs across your devices — the biggest standalone win and the whole storage/image/migration backbone.
- **Push** owned recipes: upsert `recipes` by UUID (+ promote `owner_id/visibility/version/date_modified/link_ids/variant_group_id`); bump `version` on content change.
- **Images:** content-hash each photo; upload to Supabase Storage if absent; maintain `recipe_images`; fetch via signed URLs; cache locally.
- **Overlays:** push/pull `recipe_overlays` (private notes/rating/madeCount) per device.
- **Pull on open;** conflict = recipe-level **last-write-wins** by `dateModified`.
- **First-login migration (spec §8):** re-mint seed UUIDs (+ remap link/variant refs); **first device migrates** silently; **later device prompts** ("add N local recipes?") — *MigrationSheet*. Idempotent via upsert-by-UUID.
- **Sync status** in Compte (synced / syncing / offline).
- **Acceptance:** add recipes+photos on phone → reinstall (or second device) → everything restores; edit on one device → appears on the other; second-device migration never duplicates; works offline then reconciles.

### Phase 3 — Friends graph
**Goal:** find and connect with friends. *(Mockup: FriendsScreen, FriendRow.)*
- **Amis hub** from Accueil: **add by exact @username** (`lookup_username`), send request; **incoming** (accept/decline) + **outgoing** (pending); accepted list; **remove / block**.
- Pending-request **badge** on the Amis entry.
- **Acceptance:** A sends → B accepts → mutual friends; decline/remove/block behave; unknown username handled; badge appears/clears.

### Phase 4 — Sharing & browsing
**Goal:** share your recipes and browse a friend's. *(Mockup: VisibilityControl, SharedBadge, FriendCookbookScreen, VisitingBand, recipeMode "visiting".)*
- **Per-recipe visibility** toggle (Privé / Partagé) on your recipe page + a "Partagé" badge; default private.
- **Browse a friend's cookbook** (online-only): their *shared* recipes only (RLS-enforced); the **"Carnet de @x"** visiting band; open a recipe in **read-only visiting mode** (no edit/variant/delete; Sous-chef works).
- **Acceptance:** A shares one recipe → B sees exactly that one in A's cookbook, read-only, with the band; private recipes never appear; offline → browse is blocked with a clear message.

### Phase 5 — Reviews
**Goal:** one review (stars + text) per friend per recipe. *(Mockup: ReviewsSection.)*
- Leave/edit/delete **your** review on a recipe you can access; list **others'** reviews (friend-of-friend visible); **owner moderation** (delete any review on their recipe).
- **Acceptance:** B reviews A's recipe; A sees it and can delete; a mutual-of-A-but-not-B sees B's review; B edits/deletes their own; one-per-author enforced.

### Phase 6 — Steal / link / fork (the hard one — do last)
**Goal:** take a friend's recipe as a locked, updating copy; fork to edit. *(Mockup: StealAction, StealPreviewSheet, LinkedControls, LinkedOwnerChip.)*
- **Link/steal:** insert `linked_recipes`; **recursively** resolve `link_ids` + variant members (dedup by id, cycle-safe); **cache content + images locally**; **preview sheet** when ≥1 extra recipe is pulled (no cap).
- **Non-friend transitive steal → immediate fork** (snapshot).
- **Linked UI:** lock + "de @x" chip; **poll-on-open update** → "Actualiser" (re-pull, keep overlay/your review).
- **Fork paths:** *Créer une variante* (new editable owned member in the — possibly mixed — variant group) and *Détacher de la source* (→ **new UUID**, remap `{{link}}`/`variant_group_id` referrers, copy overlay, drop the link). 
- **Owner deletes → auto-fork** from the local cache (re-register/re-upload images from cache as needed).
- **Acceptance:** steal a recipe with a linked dependency (preview shows it) → both land; owner edits → "Actualiser" pulls; *Créer une variante* and *Détacher* both work and rewrite references correctly; owner deletes → your copy auto-forks and keeps its images; dedup avoids re-importing recipes you already have.

### Phase 7 — Hardening, polish, and (optional) R2
**Goal:** make it durable and pleasant.
- **Image GC:** orphan cleanup (zero `recipe_images` refs) via a scheduled job, with a **tombstone grace period** for offline-fork safety.
- **Coach marks** (existing machinery) for social firsts: first friend, first shared recipe, first stolen recipe. **Empty/teaching states**: no friends, friend shared nothing, offline-in-cookbook, no reviews.
- **Offline reconciliation queue**, robust error/rate-limit handling, accurate sync status, block edge-cases.
- **(If needed) migrate images to Cloudflare R2** behind the same `SyncBackend`/content-addressing — set up R2 + a Supabase Edge Function for signed URLs (§A).
- **Acceptance:** GC reclaims orphaned blobs (and never live ones); offline→online reconciles; errors surface gracefully; (R2, if adopted) images serve through the new path with no app-logic change.

---

## D. Ordering rationale
Auth → **personal sync** → friends → share/browse → reviews → steal → polish. Personal multi-device sync comes before any social because it exercises the entire storage/image/migration pipeline with zero friend-graph complexity (and is independently valuable). Steal/fork is last because it depends on sharing, browsing, and the image/fork machinery all being solid. Every phase is shippable behind the optional-login gate, so you can release incrementally and stop at any point with a coherent app.
