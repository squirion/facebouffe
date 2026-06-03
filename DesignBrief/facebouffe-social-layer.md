# Facebouffe — Social Layer (Phase 2) — Architecture Draft

> **Status:** design draft for chewing, not final. Scopes a *limited release* (friends-scale) that can grow. Companion to the main design brief; nothing here is built yet.

## 0. Goals & decisions (recap)
- **Share recipes between friends + give feedback** (one review = stars + text per friend per recipe).
- **Login is optional**; required only for the social layer. Login also gives **multi-device sync** of your own cookbook.
- **Local-first always.** The app fully works offline; the cloud is a replication + rendezvous layer. No network ⇒ no social, everything else fine.
- **Find friends by exact username** (no global/browsable directory); friend requests must be **accepted**. Usernames are **unique and fixed**; the immutable **account id** is the real internal key.
- **Browse a friend's cookbook**, open/cook their recipes (with a "you're in someone else's cookbook" cue).
- **"Steal this recipe" = a locked, read-only linked copy** that updates when the owner updates. To edit: **make a variant** or **unlink from source** (→ new UUID). Owner deletion **auto-unlinks** (forks). Stealing pulls **links + variants recursively** (deduped, cycle-safe). Stealing from a friend's *linked* recipe whose canonical owner you're **not** friends with **forks immediately** (snapshot).
- **Three layers per recipe UUID:** owner **content** (owner-editable) · **comments/reviews** (shared, visible to everyone with access) · **private overlay** (your notes/lastCooked/madeCount, never shared).
- **Comments are friend-of-friend visible** (semi-public to everyone with access to the recipe). Author edits/deletes own; **owner moderates**. No aggregate rating — per-comment stars only.
- **Images are always shared**, content-addressed + reference-counted for safe GC.
- **Infra:** **Supabase** (Postgres + Auth magic-link + Storage/RLS) + **Cloudflare R2** (S3-compatible, no-egress) for image blobs. Free tiers cover the limited release. **Portability is a hard requirement** → keep everything to standard Postgres + S3 + a thin client boundary so hosts can be swapped.
- **Updates: poll-on-open** (no push in v1). **Sync conflicts (own recipes across own devices): recipe-level last-write-wins** by `dateModified`.

---

## 1. The three-layer recipe model
A recipe UUID is global identity with one canonical owner. Around it:

| Layer | Table | Editable by | Visible to | Survives owner content-update? |
|---|---|---|---|---|
| **Content** | `recipes` | owner only (`version`++ on edit) | owner + accepted friends (if `visibility='friends'`) + anyone who linked it | n/a (it *is* the update) |
| **Reviews** | `comments` | each author (own row); owner can delete (moderation) | anyone who can read the recipe | yes (separate rows) |
| **Private overlay** | `recipe_overlays` | you only | you only | yes (separate rows) |

- Content holds title/ingredients/steps/tags/links/gallery/nutrition as a **JSONB blob** (the app already serializes to JSON; keeps the cloud schema portable). A few fields are promoted to columns for RLS/queries/traversal.
- Image bytes never live in Postgres — content references images **by content hash**; blobs live in R2.
- "My cookbook" = recipes I **own** (`recipes.owner_id = me`) ∪ recipes I've **linked** (`linked_recipes`).

---

## 2. Postgres schema (draft DDL)
```sql
-- Profiles (1:1 with auth.users). Username is unique + fixed.
create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  username     text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text,
  created_at   timestamptz not null default now()
);

-- Friendships: one row per pair, canonical order (a < b). Directional blocks separate.
create table friendships (
  user_a       uuid not null references profiles(id) on delete cascade,
  user_b       uuid not null references profiles(id) on delete cascade,
  requested_by uuid not null references profiles(id),
  status       text not null default 'pending' check (status in ('pending','accepted')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create table blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);

-- Canonical recipe content (the "owner content" layer).
create table recipes (
  id               uuid primary key,                 -- the recipe's global UUID
  owner_id         uuid not null references profiles(id) on delete cascade,
  visibility       text not null default 'private' check (visibility in ('private','friends')),
  version          int  not null default 1,          -- bumps on content edit (drives "update available")
  date_modified    timestamptz not null default now(),
  content          jsonb not null,                   -- title, ingredients[], steps[], tags[], gallery[], nutrition, …
  link_ids         uuid[] not null default '{}',     -- denormalized from content for recursive-steal traversal
  variant_group_id uuid,                              -- denormalized; group membership for traversal
  created_at       timestamptz not null default now()
);
create index on recipes (owner_id);
create index on recipes (variant_group_id);

-- Each user's "stolen" read-only subscriptions (owned recipes are not listed here).
create table linked_recipes (
  user_id         uuid not null references profiles(id) on delete cascade,
  recipe_id       uuid not null references recipes(id) on delete cascade,
  source_owner_id uuid not null references profiles(id),
  linked_version  int  not null,                     -- version we last pulled (compare to recipes.version)
  added_at        timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

-- Per-user private overlay (notes/lastCooked/madeCount) — for owned AND linked recipes.
create table recipe_overlays (
  user_id     uuid not null references profiles(id) on delete cascade,
  recipe_id   uuid not null,                          -- not FK: must survive owner-delete→fork transitions
  notes       text not null default '',
  last_cooked timestamptz,
  made_count  int  not null default 0,
  updated_at  timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

-- Reviews (shared layer). One per (recipe, author).
create table comments (
  id         uuid primary key default gen_random_uuid(),
  recipe_id  uuid not null references recipes(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
  stars      int  not null check (stars between 1 and 5),
  text       text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recipe_id, author_id)
);

-- Content-addressed image registry (bytes in R2). recipe_images is the ref count.
create table images (
  hash         text primary key,                      -- sha-256 of bytes
  r2_key       text not null,
  content_type text not null,
  size_bytes   bigint not null,
  created_at   timestamptz not null default now()
);
create table recipe_images (
  recipe_id  uuid not null references recipes(id) on delete cascade,
  image_hash text not null references images(hash),
  primary key (recipe_id, image_hash)
);
-- GC: an image is orphaned when no recipe_images row references its hash.
-- Run periodically (edge function/cron); see §5.
```

---

## 3. Row-Level Security (representative policies)
RLS helpers live in a **`private` schema** (NOT the API-exposed `public`) so they can't be called as REST RPCs — they exist only to be referenced inside policies. Grant `execute` to `authenticated` so policy evaluation works.
```sql
create schema if not exists private;

create or replace function private.is_friend(u1 uuid, u2 uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships f
    where f.status = 'accepted'
      and f.user_a = least(u1,u2) and f.user_b = greatest(u1,u2)
  );
$$;

create or replace function private.can_read_recipe(rid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from recipes r where r.id = rid and (
      r.owner_id = auth.uid()
      or (r.visibility = 'friends' and private.is_friend(r.owner_id, auth.uid()))
      or exists (select 1 from linked_recipes l where l.recipe_id = rid and l.user_id = auth.uid())
    )
  );
$$;
revoke all on function private.is_friend(uuid,uuid)    from public;
revoke all on function private.can_read_recipe(uuid)   from public;
grant usage   on schema   private                       to authenticated;
grant execute on function private.is_friend(uuid,uuid)  to authenticated;
grant execute on function private.can_read_recipe(uuid) to authenticated;
```
```sql
-- recipes
alter table recipes enable row level security;
create policy recipes_read   on recipes for select using ( private.can_read_recipe(id) );
create policy recipes_write  on recipes for all    using ( owner_id = auth.uid() ) with check ( owner_id = auth.uid() );

-- comments
alter table comments enable row level security;
create policy comments_read  on comments for select using ( private.can_read_recipe(recipe_id) );
create policy comments_author on comments for insert with check ( author_id = auth.uid() and private.can_read_recipe(recipe_id) );
create policy comments_edit  on comments for update using ( author_id = auth.uid() );
create policy comments_delete on comments for delete using (   -- author OR recipe owner (moderation)
  author_id = auth.uid()
  or exists (select 1 from recipes r where r.id = recipe_id and r.owner_id = auth.uid())
);

-- recipe_overlays (private to each user)
alter table recipe_overlays enable row level security;
create policy overlay_self on recipe_overlays for all using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

-- linked_recipes (your own subscriptions)
alter table linked_recipes enable row level security;
create policy linked_self  on linked_recipes for all using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

-- profiles
alter table profiles enable row level security;
create policy profiles_read on profiles for select using ( id = auth.uid() or private.is_friend(id, auth.uid()) );
-- a user creates/edits only their own profile row (required for username claim)
create policy profiles_insert on profiles for insert with check ( id = auth.uid() );
create policy profiles_update on profiles for update using ( id = auth.uid() ) with check ( id = auth.uid() );

-- friendships (manage rows you're part of; can't accept your own request)
alter table friendships enable row level security;
create policy friendships_read   on friendships for select using ( user_a = auth.uid() or user_b = auth.uid() );
create policy friendships_insert on friendships for insert
  with check ( requested_by = auth.uid() and (user_a = auth.uid() or user_b = auth.uid()) and status = 'pending' );
create policy friendships_update on friendships for update
  using  ( user_a = auth.uid() or user_b = auth.uid() )
  with check ( (user_a = auth.uid() or user_b = auth.uid()) and (status <> 'accepted' or requested_by <> auth.uid()) );
create policy friendships_delete on friendships for delete using ( user_a = auth.uid() or user_b = auth.uid() );

-- blocks (only the blocker manages their blocks)
alter table blocks enable row level security;
create policy blocks_all on blocks for all using ( blocker_id = auth.uid() ) with check ( blocker_id = auth.uid() );

-- images / recipe_images: RLS on, NO client policies (default-deny). Maintained
-- server-side (a trigger or the service role) in the image-sync phase; clients
-- never touch these tables directly — they read images via signed URLs.
alter table images enable row level security;
alter table recipe_images enable row level security;
```
**Friend-finding without a directory:** a `security definer` RPC in `public` (so it *is* callable), but **signed-in users only** — exact match, never partial:
```sql
create or replace function lookup_username(handle text)
returns table (id uuid, username text, display_name text)
language sql stable security definer set search_path = public as $$
  select id, username, display_name from profiles where username = lower(handle) limit 1;
$$;
revoke all on function lookup_username(text) from public, anon;  -- not callable anonymously
grant execute on function lookup_username(text) to authenticated;
```
*(Images are read via signed URLs minted server-side after a `can_read_recipe` check; `images`/`recipe_images` stay client-locked. The Security Advisor will still flag `lookup_username` as an authenticated-callable SECURITY DEFINER function — that one is **intentional**.)*

---

## 4. Steal / link / fork lifecycle (table-level)
- **Steal (friends with the canonical owner):** insert `linked_recipes(me, rid, owner, version)`; recursively link `link_ids` + variant-group members (skip any already owned/linked — dedup by recipe_id; track visited for cycles). The device **caches content + images locally** (offline + future-fork safety). No `recipes`/`recipe_images` rows for the linker — content is read from the owner's row via RLS.
  - **Preview before committing:** whenever the bundle pulls in **≥1 additional** recipe (links/variants), show what's coming ("+N recettes liées") before confirming. **No cap** on count.
- **Make a variant from a linked recipe:** the new variant is **yours** (new UUID, editable) and joins the recipe's variant group. **A group may hold a mix of linked (read-only) and owned (editable) members** locally — only the owned ones are editable; the linked ones still track their sources.
- **Update available:** on open, compare `recipes.version` vs `linked_recipes.linked_version`; if newer, offer pull → re-fetch content/images, bump `linked_version`. **Private overlay + my comment are untouched** (separate rows).
- **Fork** (unlink, edit-as-mine, owner-deleted, or transitive-from-non-friend): create a **new `recipes` row owned by me with a new UUID** from the cached content; **remap** internal `{{link:id}}` tokens + `variant_group_id` from the old UUIDs to my local ones; register `recipe_images` rows (re-upload bytes from the local cache only if the blob is gone); **copy my overlay** to the new id; delete the `linked_recipes` row. Comments do **not** carry (new identity → fresh reviews).
- **Owner deletes recipe:** delete the `recipes` row (cascades `comments`, `recipe_images`). Each stealer's `linked_recipes` row dangles; on next sync the client detects the source is unreadable and **auto-forks from its local cache** (above).

---

## 5. Images — content-addressed + ref-counted GC
- Upload: hash bytes (sha-256) → if `images.hash` exists, reuse; else PUT to R2 + insert. Recipe content stores hashes; on each recipe upsert, reconcile `recipe_images` rows to match the hashes in content.
- **Orphan = a hash with zero `recipe_images` rows.** A periodic job deletes orphaned R2 objects + `images` rows.
- **Why this survives owner-delete-while-stealers-offline:** forks re-register the same hashes (dedup → usually no new bytes), and because each stealer **cached the image bytes locally at steal time**, a fork can **re-upload from cache** if the blob was already GC'd. Optional belt-and-suspenders: a **tombstone grace period** (e.g. keep orphaned blobs N days) before hard delete.
- Cost control levers for later (not v1): per-user storage quotas; stricter downscale; lazy image pull on linked recipes.

---

## 6. Client boundary — `SyncBackend` (portability)
All cloud access goes through one Dart interface (one Supabase implementation today) so the host is swappable:
```
abstract class SyncBackend {
  // auth
  Future<void> signInWithMagicLink(String email);
  Future<void> signOut();
  Account? get currentAccount;                 // null = offline/local-only

  // identity & friends
  Future<void> ensureProfile(String username);
  Future<UserRef?> lookupUsername(String handle);
  Future<void> requestFriend(String userId);
  Future<void> respondToRequest(String userId, bool accept);
  Future<List<Friend>> listFriends();
  Future<void> removeFriend(String userId);
  Future<void> block(String userId);

  // my cookbook (owned)
  Future<void> pushRecipe(Recipe r);           // upsert by UUID; bumps version
  Future<void> deleteRecipe(String id);
  Future<Cookbook> pullMyCookbook();           // owned + linked refs + overlays

  // browsing & stealing
  Future<List<RecipeStub>> browseFriendCookbook(String friendId);
  Future<Recipe> pullRecipe(String id);
  Future<StealResult> linkRecipe(String id);   // resolves the recursive bundle
  Future<Map<String,int>> checkUpdates(List<String> linkedIds);  // id -> current version
  Future<String> unlinkRecipe(String id);      // -> new local UUID (fork)

  // reviews & overlay
  Future<void> upsertComment(String recipeId, int stars, String text);
  Future<void> deleteComment(String recipeId, String authorId);
  Future<List<Comment>> listComments(String recipeId);
  Future<void> pushOverlay(String recipeId, Overlay o);

  // images
  Future<String> uploadImage(Uint8List bytes); // -> content hash
  Future<Uri> imageUrl(String hash);           // -> short-lived signed URL
}
```

---

## 7. Sync model
- **Trigger:** poll-on-open (app foreground, opening a recipe / friend's cookbook). No push in v1.
- **Own recipes ↔ own devices:** bidirectional; **recipe-level last-write-wins** by `dateModified` (single user rarely edits the same recipe on two devices at once).
- **Linked recipes:** pull-only, read-only → no conflicts ever.
- **Browsing a friend's cookbook is online-only.** Their shared recipes are *not* cached locally until you **steal** one (which then caches content + images on-device for offline use + fork safety).
- **Offline:** everything works; social calls queue/no-op and reconcile on reconnect.

---

## 8. Auth & migration (first-login flow)
- **Sign-in:** email **magic link** (Supabase). On first sign-in, prompt for a **unique fixed username** → `ensureProfile`.
- **Re-mint seed UUIDs.** Seed recipes ship with fixed ids shared across every install → they'd collide in a UUID-keyed pool. At migration (or better, at install), assign seed recipes **fresh per-install UUIDs** and remap their link/variant references. After this, *every* local recipe has a globally-unique id.
- **Idempotent migration:** upload owned recipes via **upsert-by-UUID** (+ a local `synced` marker) so re-running/interrupted migration never duplicates.
- **Avoid cross-device duplicates:**
  - **First device** to sign in (cloud cookbook empty) → migrate everything (upsert recipes, upload images, push overlays).
  - **Later devices** (cloud cookbook non-empty) → **pull first**, then show local-only recipes (UUIDs absent from the cloud) as an explicit *"Add these N recipes to your account?"* prompt — never blind-upload (two devices independently typed "the same" dish under different UUIDs and can't be auto-merged).

---

## 9. Out of scope for v1 (future levers)
- Push notifications (FCM/APNs) — replace poll-on-open later.
- Private "feedback to owner only" DMs (comments are semi-public by design).
- Aggregate ratings / discovery beyond exact-username add.
- Per-blob image ACLs (capability/signed URLs are enough at limited scale).
- Abuse reporting / richer moderation beyond owner-delete + block.

---

## 10. Resolved decisions (v1)
1. **Friend cookbooks are online-only** — a friend's shared recipes are viewed live and cached only on **steal** (§7, §4).
2. **Overlay syncs across your devices** — it's tied to the account and stored server-side (`recipe_overlays`), private to you, and persists across owner updates + carries on fork (§1, §4).
3. **A variant group may mix linked + owned members** — making a variant from a linked recipe adds an editable owned member alongside the read-only linked ones; no group fork required (§4).
4. **Steal always previews when it drags in ≥1 other recipe** ("+N recettes liées"); **no cap** on bundle size (§4).

---

## 11. UI — screens & access
Same block format as the main brief (**Purpose · Access · Key UI · States · Mockup seed**). The social layer **reuses existing surfaces** wherever it can (recipe page, Sous-chef, Settings) and adds a few new screens. The bottom tab bar **stays at four** (Accueil / Recherche / Liste / Réglages) — social is reached contextually, not via a new tab.

### Navigation map
- **Logged-out (default):** the app looks exactly as today. The only social touchpoint is a **"Se connecter"** row in Réglages. Tapping any social affordance that somehow surfaces while logged-out routes here first.
- **Logged-in:** two entry points light up —
  - **Accueil → "Amis"** (a section/button at the top of Home): the social hub — friends, requests, browsing their cookbooks. Carries a **badge** when friend requests are pending.
  - **Réglages → "Compte"**: account, username, sync status, sign-out (config lives in Settings, consistent with the app).
- **The recipe page is context-aware** — it renders in one of three modes (your own / visiting a friend's / a linked copy in your book), each adding a few affordances to the page you already have.
- **A persistent "visiting" cue** (e.g. a tinted top band "Carnet de @marie") whenever you're inside someone else's cookbook or recipe.

### Screen — Connexion (sign-in)
- **Purpose.** Optionally sign in to unlock social + multi-device sync.
- **Access.** Réglages → "Se connecter".
- **Key UI.** Brief explainer ("La connexion est optionnelle — elle active le partage et la synchro"), an **email field → "Envoyer le lien magique"**, then a **"Vérifiez vos courriels"** waiting state. Completing the magic link (deep link back into the app) signs you in. First-ever sign-in continues to **username setup**.
- **States.** Sending / sent / link-expired-retry / offline (disabled with a note). Already-signed-in → shows Compte instead.
- **Mockup seed.** "Sign-in screen: a friendly one-line explanation that login is optional, an email field with a 'Envoyer le lien magique' button, and the post-send 'Vérifiez vos courriels' state."

### Screen — Choix du nom d'utilisateur (first sign-in only)
- **Purpose.** Pick the unique, **fixed** handle friends use to find you.
- **Access.** Auto, once, right after the first successful sign-in.
- **Key UI.** Username field with **live availability check** (✓ disponible / ✗ déjà pris / format invalide), a note that it's permanent, a "Continuer" button.
- **States.** Checking / available / taken / invalid characters.
- **Mockup seed.** "Username picker: a single field showing a green 'disponible' check, a note 'Ce nom est permanent', and a Continuer button."

### Screen — Compte (account)
- **Purpose.** Manage the logged-in account + see sync health.
- **Access.** Réglages → "Compte" (replaces "Se connecter" once logged in).
- **Key UI.** Username + email; **sync status** ("Synchronisé · il y a 2 min" / "Synchronisation…" / "Hors ligne"); **Se déconnecter** (warns that social/sync pause but the local book stays); entry to the **first-login migration** prompt if pending.
- **States.** Synced / syncing / offline / sign-out confirm.
- **Mockup seed.** "Account screen: username + email, a 'Synchronisé · il y a 2 min' status line, and a Se déconnecter button with a reassuring note that recipes stay on the device."

### Screen — Amis (friends hub)
- **Purpose.** The social home: manage friends, requests, and jump into their cookbooks.
- **Access.** Accueil → "Amis".
- **Key UI.** An **"Ajouter un ami"** field (exact **@username**, → request sent); **Demandes reçues** (accept / decline) and **envoyées** (pending); the **accepted-friends list**, each row tapping through to that friend's cookbook; per-friend overflow → **retirer / bloquer**.
- **States.** No friends yet (teaching empty state: "Ajoutez un ami par son nom d'utilisateur"); request pending/accepted; username not found; blocked list.
- **Mockup seed.** "Amis screen: an 'Ajouter un ami' @username field, a 'Demandes reçues' section with accept/decline on one request, and a list of accepted friends each with an avatar-initial chip in their recipe color, tappable into their cookbook."

### Screen — Carnet d'un ami (friend's cookbook)
- **Purpose.** Browse a friend's **shared** recipes (online-only; cached only on steal).
- **Access.** Amis → tap a friend.
- **Key UI.** Looks like Home's library but **scoped to the friend**, with the persistent **"Carnet de @marie"** cue; their shared recipes as cards (private ones never appear); tap → their recipe in **visiting mode**.
- **States.** Online required (offline → "Reconnectez-vous pour voir le carnet de @marie"); friend has shared nothing yet; loading.
- **Mockup seed.** "A friend's cookbook: a tinted 'Carnet de @marie' band on top, then a grid of her shared recipe cards (some with fallback-color tiles), in the same visual language as Home."

### Recipe page — mode A: visiting a friend's recipe
- **Purpose.** Read/cook a friend's recipe and react to it.
- **Access.** From a friend's cookbook (or a friend's inline link).
- **Key UI (added to the normal recipe page).** The **"Carnet de @marie"** cue; everything **read-only**; **Mode sous-chef works**; an **"Voler cette recette"** primary action; the **Avis** section (your single review to add/edit + others' reviews). No edit/variant/delete (those are owner-only).
- **States.** Already stolen → the steal button becomes "Déjà dans votre carnet"; review not yet written vs written.
- **Mockup seed.** "Friend's recipe in visiting mode: the standard recipe page under a 'Carnet de @marie' band, action row reduced to 'Voler cette recette' + 'Mode sous-chef', and an 'Avis' section showing the viewer's star input plus two friends' reviews."

### Recipe page — mode B: your own recipe (sharing + moderation)
- **Purpose.** Control who sees it and manage feedback.
- **Access.** Your own recipe page (logged-in).
- **Key UI (added).** A **visibility control** — **Privé / Partagé avec mes amis** (a toggle near the title/tags), with a subtle "Partagé" indicator on shared recipes; the **Avis** section listing friends' reviews with **delete (moderation)** on each.
- **States.** Private (default) vs shared; no reviews yet; logged-out → control hidden.
- **Mockup seed.** "Your recipe page with a 'Partagé avec mes amis' toggle beside the tag row, a small 'Partagé' badge, and an Avis section listing two friends' star+text reviews each with a moderation trash icon."

### Recipe page — mode C: a linked (stolen) recipe in your book
- **Purpose.** Use a stolen recipe; pull updates; fork to edit.
- **Access.** Your own library (a recipe you stole).
- **Key UI (added).** A **lock + "de @marie"** marker; an **"Mise à jour disponible — Actualiser"** banner when the owner's version advanced (poll-on-open); editing is blocked, and the edit/variant entry instead offers **"Créer une variante"** or **"Détacher de la source"**. Your **private notes/rating still work** (overlay).
- **States.** Up-to-date vs update-available; source deleted → auto-forked notice ("Cette recette a été détachée — l'auteur l'a retirée").
- **Mockup seed.** "A stolen recipe in your book: a lock chip 'de @marie', an 'Mise à jour disponible · Actualiser' banner, the edit button replaced by a menu offering 'Créer une variante' / 'Détacher de la source', and private notes still editable below."

### Sheet — Aperçu du vol (steal preview)
- **Purpose.** Confirm a steal that pulls in linked/variant recipes.
- **Access.** Tapping "Voler cette recette" when the bundle includes ≥1 extra recipe.
- **Key UI.** "Cette recette en entraîne d'autres" + a short list of the additional recipes (links + variants) that will join your book; **Tout ajouter** / Annuler. (If nothing extra, steal happens directly with no sheet.)
- **States.** 1 vs many extras; some already in your book (shown as "déjà présent", skipped).
- **Mockup seed.** "Steal-preview bottom sheet: 'Voler « Gâteau » ajoutera aussi 2 recettes liées' with a small list (Glaçage, Sirop) and a 'Tout ajouter' button."

### Sheet — Migration à la première connexion
- **Purpose.** Bring existing local recipes into the account without duplicates.
- **Access.** Auto on first sign-in (first device migrates silently); on a **later device** it appears as a prompt.
- **Key UI.** "Vous avez N recettes sur cet appareil qui ne sont pas dans votre compte — les ajouter ?" with **Ajouter / Plus tard**.
- **States.** First device (no prompt, just a synced toast) vs later device (prompt with count) vs nothing to migrate.
- **Mockup seed.** "First-login migration sheet on a second device: 'Vous avez 5 recettes locales absentes de votre compte — les ajouter ?' with Ajouter / Plus tard."

### Cross-cutting UI additions
- **Coach marks (§3.7 of the brief, same machinery):** first friend added, first recipe shared (the visibility toggle), first stolen recipe (the lock + fork menu). One at a time.
- **Empty/teaching states:** no friends, friend shared nothing, offline-in-a-friend's-cookbook, no reviews yet.
- **Badges:** pending friend-requests on the Amis entry; "Mise à jour disponible" on linked recipes.
- **Everything bilingual FR/EN**, short labels; the "visiting" cue and read-only state must be unmistakable so a friend's recipe is never confused with your own.
