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

  // Standards & audit evidence — added 2026-10-06. Organised by the evidence a
  // customer owes rather than by SKU, deliberately: the per-product claim set is
  // the catalog's job, and splitting this by product reproduces it badly.
  "/standards":  "/standards.html",
  "/compliance": "/standards.html",

  // Core pages
  "/about":   "/about.html",
  "/docs":    "/docs.html",
  "/verify":  "/verify.html",
  // Contact — added 2026-09-18 with its asset in the same change. Every nav
  // "Contact" was a bare mailto:, which does nothing on a machine with no mail
  // client configured (operator reproduced it 2026-09-18). The page shows the
  // address as copyable text and pre-fills subjects; the mailto: is a link on
  // the page, not the destination of the button.
  "/contact": "/contact.html",
  // Stripe Payment Links redirect here after a completed checkout.
  "/thanks":  "/thanks.html",
  // Support + Ciborium — added 2026-10-14 with their assets in the same change.
  // /support#partners is where investor/partner traffic is sent from /ciborium.
  "/support":  "/support.html",
  "/ciborium": "/ciborium.html",
  "/wallet":   "/ciborium.html",
  // Services — added 2026-10-18 with its asset in the same change
  // (CCPROMPT-CONSULT-LEASE-001 Task 7, copy Candidate A). Not linked from the
  // nav: the nav is hard-coded in every page and is a separate ruling.
  "/services": "/services.html",

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

// Permanent redirects.
//
// 2026-10-22: the five /products/* redirects were removed (operator ruling). No
// PowerVerify unit was ever sold to a customer, so no resin QR code in the field
// points at /products/powerverify, and our own pages now link to the category pages
// directly. /shop and /buy stay: they are typed or spoken entry points, not old URLs.
const REDIRECTS = {
  // Storefront entry points. The buy buttons live on the category pages; these
  // exist so "zknot.io/shop" typed from a label or said aloud lands somewhere.
  "/shop":                   "/verifiables#products",
  "/buy":                    "/verifiables#products",
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
