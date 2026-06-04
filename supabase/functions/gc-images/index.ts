// Image garbage collection (Facebouffe social layer §5).
//
// Deletes content-addressed image blobs that nothing references anymore — a
// hash with zero `recipe_images` rows AND not used as a `profiles.avatar_hash`.
// A tombstone grace period protects offline stealers: an image is first *marked*
// orphaned (orphaned_at), and only hard-deleted once it has stayed orphaned for
// GRACE_DAYS — long enough for an offline fork to re-register/re-upload it.
//
// Runs with the service-role key (server-only). Schedule it daily (see
// supabase/README-gc.md). Idempotent and safe to run repeatedly.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GRACE_DAYS = 7;
const BUCKET = "recipe-images";

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1) (re)compute tombstones: mark newly-orphaned, clear re-referenced.
  const { error: sweepErr } = await supabase.rpc("gc_sweep_orphans");
  if (sweepErr) {
    return new Response(JSON.stringify({ error: sweepErr.message }), { status: 500 });
  }

  // 2) hard-delete blobs that have stayed orphaned past the grace period.
  const cutoff = new Date(Date.now() - GRACE_DAYS * 86_400_000).toISOString();
  const { data: dead, error: selErr } = await supabase
    .from("images")
    .select("hash, r2_key")
    .not("orphaned_at", "is", null)
    .lt("orphaned_at", cutoff);
  if (selErr) {
    return new Response(JSON.stringify({ error: selErr.message }), { status: 500 });
  }

  let deleted = 0;
  if (dead && dead.length > 0) {
    const keys = dead.map((d: { r2_key: string }) => d.r2_key);
    const hashes = dead.map((d: { hash: string }) => d.hash);
    // remove the storage objects first; only drop the registry rows if that succeeds
    const { error: rmErr } = await supabase.storage.from(BUCKET).remove(keys);
    if (rmErr) {
      return new Response(JSON.stringify({ error: rmErr.message }), { status: 500 });
    }
    const { error: delErr } = await supabase.from("images").delete().in("hash", hashes);
    if (delErr) {
      return new Response(JSON.stringify({ error: delErr.message }), { status: 500 });
    }
    deleted = dead.length;
  }

  return new Response(JSON.stringify({ ok: true, deleted }), {
    headers: { "content-type": "application/json" },
  });
});
