// router.js — ZKNOT™ site router for Cloudflare Workers
// Assets live in ./public/ — this script handles clean URL routing

const ROUTES = {
  "/":                             "/index.html",
  "/products/zkkey":               "/zkkey.html",
  "/products/powerverify":         "/powerverify.html",
  "/products/zk-localchain":       "/zk-localchain.html",
  "/products/trustseal":           "/trustseal.html",
  "/protocol":                     "/protocol.html",
  "/evidence-protocol":            "/protocol.html",
  "/verticals/journalism":         "/journalism.html",
  "/verticals/pharmaceutical":     "/pharmaceutical.html",
  "/verticals/law-enforcement":    "/law-enforcement.html",
  "/verticals/election-integrity": "/vertical-election.html",
  "/about":                        "/about.html",
  "/docs":                         "/docs.html",
  "/verify":                       "/verify.html",
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
      const assetRequest = new Request(
        new URL(mapped, url.origin).toString(),
        request
      );
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
    }

    // Fall through to asset serving (favicon, images, etc.)
    return env.ASSETS.fetch(request);
  },
};
