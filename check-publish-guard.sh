#!/usr/bin/env bash
# check-publish-guard.sh — zknot.io publish dead-name guard (v3 semantics, first
# time committed as an artifact).
#
# PROVENANCE. OPS/journal/2026-07-24_ripple-content-pass.md open item 10 records:
# "COPY CLEAN runs in the site repo Sunday — the guard does not exist in this
# vault and the manifest had no site files." It never landed. This file is a
# reconstruction of the v3 SEMANTICS described in that journal and in
# 00_INBOX/CC-PROMPT_ripple-content-pass_20260724.md, not a recovered copy. Treat
# its verdict as this script's opinion; the evidence is the grep output it prints.
#
# WHAT v3 CHECKS (per the ripple journal, decision 3):
#   - DISPLAY TEXT only. Dead product names rendered to a human are failures.
#   - Route paths, href targets, anchor ids and 301 lines are ALLOWLISTED. They
#     are documented load-bearing deep links; fragments never reach the server.
#   - Internal codenames are NOT dead names: ZKKey (infra/ledger lineage),
#     Redoubt, P-ATTZ, WM- serials, the WITNESSMARK_UNIT api enum.
#     Those are per ~/ZKNOT/CLAUDE.md "Naming" and never fail this guard.
#
# USAGE
#   ./check-publish-guard.sh            # check public/ as shipped
#   ./check-publish-guard.sh --served   # ALSO fetch live zknot.io and check that
#
# EXIT 0 = COPY CLEAN. EXIT 1 = dead display text found.

set -uo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
PUB="$SRC/public"
FAIL=0

# Public renames per 00_COMMAND/BRAND-REGISTRY-001. Left side = dead display name.
DEAD_NAMES=(
  "WitnessMark"
  "Attestor"
  "TrustSeal"
  "ZK-LocalChain"
  "ZKKey"
)

# Strip everything a reader never sees, then look for dead names in what is left.
#   - HTML comments
#   - the contents of every attribute (href/id/class/src/data-*) — routes and
#     anchor ids live here and are allowlisted by decision 3
#   - <script> and <style> bodies
strip_to_display_text() {
  python3 - "$1" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
src = re.sub(r"<!--.*?-->", " ", src, flags=re.S)
src = re.sub(r"<script\b.*?</script>", " ", src, flags=re.S | re.I)
src = re.sub(r"<style\b.*?</style>", " ", src, flags=re.S | re.I)
# drop every tag WITH its attributes; keep only the text between tags
src = re.sub(r"<[^>]*>", "\n", src)
sys.stdout.write(src)
PY
}

scan_dir() {
  local dir="$1" label="$2"
  echo "── scanning $label"
  local found=0
  for f in "$dir"/*.html; do
    [ -e "$f" ] || continue
    local text
    text="$(strip_to_display_text "$f")"
    for name in "${DEAD_NAMES[@]}"; do
      local hits
      hits="$(printf '%s' "$text" | grep -c -F "$name" || true)"
      if [ "$hits" -gt 0 ]; then
        printf '   DEAD  %-24s %-16s x%s\n' "$(basename "$f")" "$name" "$hits"
        found=$((found + hits))
      fi
    done
  done
  if [ "$found" -gt 0 ]; then
    echo "   → $found dead-name occurrences in display text"
    FAIL=1
  else
    echo "   → clean"
  fi
}

echo "════ zknot.io publish dead-name guard v3"
scan_dir "$PUB" "shipped tree: public/"

if [ "${1:-}" = "--served" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "── fetching live routes from https://zknot.io"
  # Routes come from router.js ROUTES — the real router. _redirects is inert on
  # this Worker+ASSETS deployment (verified: /shop returns 404, no catch-all).
  python3 - "$SRC/router.js" > "$TMP/routes.txt" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
block = re.search(r"const ROUTES = \{(.*?)\n\};", src, re.S).group(1)
for m in re.finditer(r'"(/[^"]*)"\s*:', block):
    print(m.group(1))
PY
  while read -r route; do
    [ -n "$route" ] || continue
    out="$TMP/$(printf '%s' "$route" | tr '/' '_').html"
    code="$(curl -s -o "$out" -w '%{http_code}' "https://zknot.io$route")"
    [ "$code" = "200" ] || { printf '   MISS  %-32s http %s\n' "$route" "$code"; FAIL=1; }
  done < "$TMP/routes.txt"
  scan_dir "$TMP" "served: zknot.io"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "✓ COPY CLEAN"
else
  echo "✗ NOT CLEAN — dead product names are rendered as display text."
  echo "  Per decision 3 (OPS/journal/2026-07-24_ripple-support-and-tm-evidence.md)"
  echo "  routes and anchor ids STAY; only display text is rewritten."
fi
exit "$FAIL"
