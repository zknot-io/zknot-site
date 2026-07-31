#!/usr/bin/env bash
# =============================================================================
# check-legal-pages.sh — pre-deploy gate for the zknot.io legal/commerce surface.
#
# PROPOSED, NOT YET RATIFIED. Modelled on hashstamp-site/check-legal-pages.sh.
# zknot.io is about to take money for PHYSICAL goods, which brings obligations
# the HashStamp digital-only surface did not: a shipping policy, a returns policy
# for a serialized one-way-door article, and PII handling for a delivery address.
#
# WHAT IS DIFFERENT FROM THE HASHSTAMP SCRIPT
#   1. zknot.io does NOT 200 every path — it is a Worker + ASSETS binding whose
#      route map is ROUTES in router.js. `_redirects` is INERT here (verified:
#      /shop returns 404, so the `/* -> /index.html 200` line does not fire).
#      So a 404 is meaningful and section 4 checks the route map, not a control
#      hash.
#   2. Section 5 is new: the /cdn-cgi/ injection check the HashStamp script has
#      no reason to carry. See the note there — on zknot.io this is NOT an edge
#      injection, it is COMMITTED SOURCE.
#
# USAGE
#   ./check-legal-pages.sh                  # static checks only
#   ./check-legal-pages.sh https://zknot.io # + live checks against production
#
# EXIT: 0 = all pass. Non-zero = do not deploy / deploy did not take.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")"

BASE="${1:-}"
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  SKIP  %s\n' "$1"; }

# The four surfaces a physical-goods storefront needs. None exist yet.
PAGES="terms.html privacy.html shipping.html returns.html"

rendered() { perl -0pe 's/<!--.*?-->//gs' "$1"; }

echo "== 1. The legal pages exist at all"
for f in $PAGES; do
  [ -f "public/$f" ] && pass "public/$f present" || fail "public/$f MISSING"
done

echo "== 2. No placeholder or internal annotation reaches a rendered page"
BANNED='__EFFECTIVE_DATE__|TODO|TBD|DRAFT|placeholder|LOREM|not customer-facing|CCPROMPT|D-[A-F]\b'
for f in $PAGES; do
  [ -f "public/$f" ] || { skip "$f (missing)"; continue; }
  hits=$(rendered "public/$f" | grep -oE "$BANNED" | sort -u | tr '\n' ' ')
  [ -n "$hits" ] && fail "$f leaks: $hits" || pass "$f clean of placeholders"
done

echo "== 3. Contact information survives with JavaScript OFF"
# A storefront that takes money must expose a reachable contact path in the HTML
# itself. A JS-dependent contact link is not contact information.
for f in public/*.html; do
  raw=$(grep -c 'mailto:' "$f" || true)
  obf=$(grep -c 'cdn-cgi/l/email-protection' "$f" || true)
  if [ "$obf" -gt 0 ]; then
    fail "$(basename "$f") has $obf JS-dependent contact link(s) and $raw raw mailto:"
  elif [ "$raw" -gt 0 ]; then
    pass "$(basename "$f") carries $raw raw mailto:"
  else
    fail "$(basename "$f") has NO contact link of any kind"
  fi
done

echo "== 4. Every legal page is reachable through the real router (router.js ROUTES)"
# _redirects is inert on this deployment. Adding a line there does NOT create a
# route. This check reads the route map that actually runs.
for r in /terms /privacy /shipping /returns; do
  grep -q "\"$r\"" router.js && pass "router.js maps $r" || fail "router.js has NO route for $r"
done

echo "== 5. No /cdn-cgi/ injection in ANY attribute on ANY page"
# READ THIS BEFORE 'FIXING' A HIT.
# On hashstamp.io this class of defect is edge-injected by Cloudflare Email
# Obfuscation with zero deploys. On zknot.io, as of 2026-07-28, it is NOT: the
# obfuscated links are COMMITTED INTO public/{zkkey,powerverify,trustseal,
# zk-localchain}.html and are in git history. Someone saved a Cloudflare-rewritten
# page back over the source. Worse, no /cdn-cgi/scripts/.../email-decode.min.js is
# served with them, so the links do not merely require JS — they are inert.
# Fixing the zone setting will NOT fix these files. They must be edited.
for f in public/*.html; do
  hits=$(grep -oE '/cdn-cgi/[^"'"'"' >]*' "$f" | sort -u | tr '\n' ' ')
  [ -n "$hits" ] && fail "$(basename "$f") contains /cdn-cgi/ reference(s): $hits" \
                 || pass "$(basename "$f") free of /cdn-cgi/"
done

if [ -n "$BASE" ]; then
  echo "== 6. LIVE — served pages match the shipped tree, and carry no edge injection"
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  for r in / /about /docs /verify /protocol; do
    code=$(curl -s -o "$TMP/p.html" -w '%{http_code}' "$BASE$r")
    if [ "$code" != "200" ]; then fail "$r -> http $code"; continue; fi
    if grep -q 'cdn-cgi' "$TMP/p.html"; then
      fail "$r served WITH /cdn-cgi/ injection (compare against the shipped file)"
    else
      pass "$r served clean"
    fi
  done
  echo "== 7. LIVE — security headers are actually present"
  # router.js defines SECURITY_HEADERS but the change is uncommitted and undeployed
  # as of 2026-07-28; this check is what proves the deploy took.
  hdrs=$(curl -s -D - -o /dev/null "$BASE/")
  for h in strict-transport-security x-content-type-options x-frame-options content-security-policy; do
    printf '%s' "$hdrs" | grep -qi "^$h:" && pass "header $h present" || fail "header $h ABSENT"
  done
else
  skip "sections 6-7 (no BASE url given)"
fi

echo
[ "$FAIL" -eq 0 ] && echo "✓ LEGAL SURFACE OK" || echo "✗ $FAIL check(s) failed — do not deploy"
exit $(( FAIL > 0 ? 1 : 0 ))
