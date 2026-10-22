const TMDB_ORIGIN = "https://api.themoviedb.org";
const API_PREFIX = "/3/";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Accept, Authorization",
};

function json(body, status = 200) {
  return Response.json(body, { status, headers: corsHeaders });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "animememo-tmdb-proxy",
        tokenConfigured: Boolean(env.TMDB_READ_ACCESS_TOKEN),
      });
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!url.pathname.startsWith(API_PREFIX)) {
      return json({ error: "Only /3/* TMDB API paths are available" }, 404);
    }

    // A client supplied token wins, so the app can still use this worker with
    // its own credentials. Otherwise the worker injects the server token.
    const clientAuth = request.headers.get("Authorization");
    const token = clientAuth?.startsWith("Bearer ")
      ? clientAuth.slice("Bearer ".length).trim()
      : env.TMDB_READ_ACCESS_TOKEN;

    if (!token) {
      return json(
        { error: "TMDB_READ_ACCESS_TOKEN secret is not configured" },
        500
      );
    }

    const target = new URL(url.pathname + url.search, TMDB_ORIGIN);
    const headers = new Headers({
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      "User-Agent": "AnimeMemo-TMDB-Proxy/0.1",
    });

    let response;
    try {
      response = await fetch(target, {
        method: request.method,
        headers,
        redirect: "follow",
        cf: { cacheTtl: 300, cacheEverything: true },
      });
    } catch (error) {
      return json(
        { error: "TMDB upstream request failed", detail: String(error) },
        502
      );
    }

    const outputHeaders = new Headers(response.headers);
    for (const [key, value] of Object.entries(corsHeaders)) {
      outputHeaders.set(key, value);
    }
    outputHeaders.set("X-Proxy", "animememo-tmdb");
    outputHeaders.set("Cache-Control", "public, max-age=300");
    outputHeaders.delete("set-cookie");

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: outputHeaders,
    });
  },
};
