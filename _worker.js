// _worker.js — ZKNOT™ site router for Cloudflare Workers
// Maps clean URLs to .html files in the asset bundle

const ROUTES = {
  // Products
  "/products/zkkey":          "/zkkey.html",
  "/products/powerverify":    "/powerverify.html",
  "/products/zk-localchain":  "/zk-localchain.html",
  "/products/trustseal":      "/trustseal.html",

  // Protocol
  "/protocol":                "/protocol.html",
  "/evidence-protocol":       "/protocol.html",

  // Verticals
  "/verticals/journalism":       "/journalism.html",
  "/verticals/pharmaceutical":   "/pharmaceutical.html",
  "/verticals/law-enforcement":  "/law-enforcement.html",
  "/verticals/election-integrity": "/vertical-election.html",

  // Core pages
  "/about":   "/about.html",
  "/docs":    "/docs.html",
  "/verify":  "/verify.html",
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
      const assetUrl = new URL(mapped, url.origin);
      const assetRequest = new Request(assetUrl.toString(), request);
      const response = await env.ASSETS.fetch(assetRequest);
      if (response.ok) {
        // Return with correct content type and original URL intact
        return new Response(response.body, {
          status: 200,
          headers: {
            "Content-Type": "text/html; charset=utf-8",
            "Cache-Control": "public, max-age=300",
            "X-Robots-Tag": "index, follow",
          },
        });
      }
    }

    // Fall through to asset serving (handles index.html, static files, etc.)
    return env.ASSETS.fetch(request);
  },
};
