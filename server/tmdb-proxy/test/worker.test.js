import test from "node:test";
import assert from "node:assert/strict";

import worker from "../src/index.js";

const ENV = { TMDB_READ_ACCESS_TOKEN: "server-token" };

function stubUpstream(handler) {
  const original = globalThis.fetch;
  const calls = [];

  globalThis.fetch = async (input, init) => {
    calls.push({ url: String(input), init });
    return handler(String(input), init);
  };

  return {
    calls,
    restore() {
      globalThis.fetch = original;
    },
  };
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

test("health reports token state", async () => {
  const response = await worker.fetch(new Request("https://proxy.test/health"), ENV);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.tokenConfigured, true);
});

test("health reports a missing token", async () => {
  const response = await worker.fetch(new Request("https://proxy.test/health"), {});
  const body = await response.json();

  assert.equal(body.tokenConfigured, false);
});

test("preflight requests get CORS headers", async () => {
  const response = await worker.fetch(
    new Request("https://proxy.test/3/tv/1", { method: "OPTIONS" }),
    ENV
  );

  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
});

test("non /3 paths are rejected", async () => {
  const response = await worker.fetch(new Request("https://proxy.test/anything"), ENV);
  assert.equal(response.status, 404);
});

test("write methods are rejected", async () => {
  const response = await worker.fetch(
    new Request("https://proxy.test/3/tv/1", { method: "POST" }),
    ENV
  );
  assert.equal(response.status, 405);
});

test("forwards /3 paths and injects the server token", async () => {
  const upstream = stubUpstream(() => jsonResponse({ id: 1, name: "Test" }));

  try {
    const response = await worker.fetch(
      new Request("https://proxy.test/3/tv/1?language=zh-CN"),
      ENV
    );

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("X-Proxy"), "animememo-tmdb");
    assert.equal(upstream.calls.length, 1);

    const [{ url, init }] = upstream.calls;
    assert.equal(url, "https://api.themoviedb.org/3/tv/1?language=zh-CN");
    assert.equal(init.headers.get("Authorization"), "Bearer server-token");
  } finally {
    upstream.restore();
  }
});

test("client supplied token wins over the server token", async () => {
  const upstream = stubUpstream(() => jsonResponse({}));

  try {
    await worker.fetch(
      new Request("https://proxy.test/3/tv/1", {
        headers: { Authorization: "Bearer client-token" },
      }),
      ENV
    );

    const [{ init }] = upstream.calls;
    assert.equal(init.headers.get("Authorization"), "Bearer client-token");
  } finally {
    upstream.restore();
  }
});

test("upstream failures become 502", async () => {
  const upstream = stubUpstream(() => {
    throw new Error("boom");
  });

  try {
    const response = await worker.fetch(new Request("https://proxy.test/3/tv/1"), ENV);
    assert.equal(response.status, 502);
  } finally {
    upstream.restore();
  }
});

test("missing server token returns 500 instead of proxying", async () => {
  const response = await worker.fetch(new Request("https://proxy.test/3/tv/1"), {});
  assert.equal(response.status, 500);
});
