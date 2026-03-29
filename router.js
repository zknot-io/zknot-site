// router.js — ZKNOT™ site router for Cloudflare Workers
// Assets live in ./public/ — this script handles clean URL routing

const ROUTES = {
  // Root
  "/":                             "/index.html",

  // Products — try both with and without leading slash variations
  "/products/zkkey":               "/zkkey.html",
  "/products/powerverify":         "/powerverify.html",
  "/products/zk-localchain":       "/zk-localchain.html",
  "/products/trustseal":           "/trustseal.html",

  // Protocol
  "/protocol":                     "/protocol.html",
  "/evidence-protocol":            "/protocol.html",

  // Verticals
  "/verticals/journalism":         "/journalism.html",
  "/verticals/pharmaceutical":     "/pharmaceutical.html",
  "/verticals/law-enforcement":    "/law-enforcement.html",
  "/verticals/election-integrity": "/vertical-election.html",

  // Core pages
  "/about":   "/about.html",
  "/docs":    "/docs.html",
  "/verify":  "/verify.html",
  "/faq":     "/faq.html",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let pathname = url.pathname;

    // Strip trailing slash (except root)
    if (pathname !== "/" && pathname.endsWith("/")) {
      pathname = pathname.slice(0, -1);
    }

    // Check route map
    const mapped = ROUTES[pathname];
    if (mapped) {
      // Try fetching the mapped asset
      const assetRequest = new Request(
        new URL(mapped, url.origin).toString(),
        { method: request.method, headers: request.headers }
      );
      try {
        const response = await env.ASSETS.fetch(assetRequest);
        if (response.ok) {
          return new Response(response.body, {
            status: 200,
            headers: {
              "Content-Type": "text/html; charset=utf-8",
              "Cache-Control": "public, max-age=300",
            },
          });
        }
      } catch (e) {
        // Fall through to direct asset serving
      }
    }

    // Fall through — serve asset directly (handles .html, .svg, .js, etc.)
    try {
      return await env.ASSETS.fetch(request);
    } catch (e) {
      return new Response("Not found", { status: 404 });
    }
  },
};
