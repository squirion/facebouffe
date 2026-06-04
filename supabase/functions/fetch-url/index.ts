// CORS proxy for recipe import on the web build.
//
// Browsers can't fetch arbitrary recipe pages (cross-origin), so the web client
// routes URL imports through this function, which fetches server-side and
// passes the response back with CORS headers. Native builds fetch directly and
// never hit this. Deploy with --no-verify-jwt (see supabase/README-gc.md note).

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const target = new URL(req.url).searchParams.get("url");
  if (target == null || !/^https?:\/\//i.test(target)) {
    return new Response("bad url", { status: 400, headers: cors });
  }

  try {
    const upstream = await fetch(target, {
      headers: { "User-Agent": UA, "Accept": "*/*", "Accept-Language": "fr-CA,fr;q=0.9,en;q=0.8" },
      redirect: "follow",
    });
    const body = await upstream.arrayBuffer();
    return new Response(body, {
      status: upstream.status,
      headers: { ...cors, "content-type": upstream.headers.get("content-type") ?? "application/octet-stream" },
    });
  } catch (_) {
    return new Response("fetch failed", { status: 502, headers: cors });
  }
});
