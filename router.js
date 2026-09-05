// router.js — ZKNOT™ site router for Cloudflare Workers
// Assets live in ./public/ — this script handles clean URL routing

// Security headers — closes WEB-01 (ZKNOT security assessment 2026-07-09).
// This Worker rebuilds every Response, so a _headers file is NOT honored here;
// these are applied in code to both response paths below.
// CSP keeps 'unsafe-inline' (verify.html uses inline handlers) — tighten to
// nonces as a P2. HSTS is per-host without includeSubDomains/preload (a near
// one-way door) until all *.zknot.io subdomains are confirmed HTTPS.
const SECURITY_HEADERS = {
  "Strict-Transport-Security": "max-age=31536000",
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Permissions-Policy": "geolocation=(), interest-cohort=()",
  "Content-Security-Policy":
    "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; " +
    "img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
    "font-src 'self' https://fonts.gstatic.com; script-src 'self' 'unsafe-inline'; " +
    "connect-src 'self' https://api.zknot.io; form-action 'self'",
};

function withSecurityHeaders(response) {
  const r = new Response(response.body, response);
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) r.headers.set(k, v);
  return r;
}

const ROUTES = {
  // Root
  "/":                             "/index.html",

  // Categories — the three-band structure that replaces the four product
  // pages. All three routed as of 2026-07-31.
  "/verifiables":                  "/verifiables.html",
  "/attestation":                  "/attestation.html",
  "/rails":                        "/rails.html",

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

  // Legal pages — added 2026-08-05 with their assets in the same change, per the
  // standing rule below. check-legal-pages.sh was failing on all four (missing
  // asset AND missing route) while shop.zknot.io was taking money with no refund,
  // terms, or shipping policy published anywhere.
  "/terms":    "/terms.html",
  "/privacy":  "/privacy.html",
  "/shipping": "/shipping.html",
  "/returns":  "/returns.html",
  // "/faq" removed 2026-08-04: it was mapped to /faq.html, which has never
  // existed, so the Worker fell through and served a ZERO-BYTE 404 — not even the
  // branded page. Nothing linked to it, so this was a latent trap rather than live
  // breakage: the first nav or footer link added would have shipped a blank 404.
  // check-publish-guard.sh --served has been reporting `MISS /faq http 404` the
  // whole time; the detection was never the gap, running it was.
  // NEVER ROUTE AHEAD OF THE ASSET. If an FAQ is wanted, add faq.html and this
  // line in the same change.
};

// Permanent redirects. The four product pages were retired 2026-07-31 and their
// content is now covered by the three category pages.
//
// These are 301s and not deletions for one reason that outranks tidiness:
// /products/powerverify is the target of the live Shopify listing AND it sits
// beside the QR code on potted PowerVerify units. A URL cast into resin cannot
// be recalled, so it must resolve forever. The other three cost nothing to keep
// and are retained for the same class of reason — inbound links we do not control.
const REDIRECTS = {
  "/products/powerverify":   "/verifiables",
  // Both spellings resolve. /products/trustseal is the RETIRED name (T-7, 2026-08-05) and is
  // kept for the reason stated above — inbound links we do not control. /products/tamperverify
  // is the current name and is what authored markup now points at, so new links stop minting
  // the dead one. Neither may be removed: the old one because it is out there, the new one
  // because it is now in our own pages.
  "/products/trustseal":     "/verifiables",
  "/products/tamperverify":  "/verifiables",
  "/products/zkkey":         "/attestation",
  "/products/zk-localchain": "/rails",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let pathname = url.pathname;

    // Strip trailing slash (except root)
    if (pathname !== "/" && pathname.endsWith("/")) {
      pathname = pathname.slice(0, -1);
    }

    // Permanent redirects run before the route map, so a retired path can never
    // be shadowed by a stale ROUTES entry.
    const redirect = REDIRECTS[pathname];
    if (redirect) {
      return withSecurityHeaders(
        Response.redirect(new URL(redirect, url.origin).toString(), 301)
      );
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
          return withSecurityHeaders(new Response(response.body, {
            status: 200,
            headers: {
              "Content-Type": "text/html; charset=utf-8",
              "Cache-Control": "public, max-age=300",
            },
          }));
        }
      } catch (e) {
        // Fall through to direct asset serving
      }
    }

    // Fall through — serve asset directly (handles .html, .svg, .js, etc.)
    try {
      return withSecurityHeaders(await env.ASSETS.fetch(request));
    } catch (e) {
      return new Response("Not found", { status: 404 });
    }
  },
};
