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
Helpers keep the access predicate in one place:
```sql
create or replace function is_friend(u1 uuid, u2 uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships f
    where f.status = 'accepted'
      and ((f.user_a = least(u1,u2) and f.user_b = greatest(u1,u2)))
  );
$$;

create or replace function can_read_recipe(rid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from recipes r where r.id = rid and (
      r.owner_id = auth.uid()
      or (r.visibility = 'friends' and is_friend(r.owner_id, auth.uid()))
      or exists (select 1 from linked_recipes l where l.recipe_id = rid and l.user_id = auth.uid())
    )
  );
$$;
```
```sql
alter table recipes enable row level security;
create policy recipes_read   on recipes for select using ( can_read_recipe(id) );
create policy recipes_write  on recipes for all    using ( owner_id = auth.uid() ) with check ( owner_id = auth.uid() );

alter table comments enable row level security;
create policy comments_read  on comments for select using ( can_read_recipe(recipe_id) );
create policy comments_author on comments for insert with check ( author_id = auth.uid() and can_read_recipe(recipe_id) );
create policy comments_edit  on comments for update using ( author_id = auth.uid() );
-- delete by author OR by the recipe owner (moderation):
create policy comments_delete on comments for delete using (
  author_id = auth.uid()
  or exists (select 1 from recipes r where r.id = recipe_id and r.owner_id = auth.uid())
);

alter table recipe_overlays enable row level security;
create policy overlay_self on recipe_overlays for all using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

alter table linked_recipes enable row level security;
create policy linked_self  on linked_recipes for all using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );

alter table profiles enable row level security;
create policy profiles_read on profiles for select using ( id = auth.uid() or is_friend(id, auth.uid()) );
```
**Friend-finding without a directory:** a `security definer` RPC, not table browsing:
```sql
create or replace function lookup_username(handle text)
returns table (id uuid, username text, display_name text)
language sql stable security definer set search_path = public as $$
  select id, username, display_name from profiles where username = lower(handle) limit 1;
$$;  -- exact match only; reveals nothing on partials → no browsing
```
*(Images are read via signed R2 URLs minted by an edge function that checks `can_read_recipe`; the `images`/`recipe_images` tables are service-role only.)*

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
