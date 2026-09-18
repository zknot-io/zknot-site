#!/usr/bin/env bash
# check-price-sources.sh — one price per SKU across zknot.io, Shopify and Stripe.
#
# CATALOG-SSOT-001 §0.3: one platform object per SKU is the charging authority.
# From 2026-09-18 two platforms charge for the same articles (operator ruling,
# session 2026-09-18: Stripe Payment Links on zknot.io AND shop.zknot.io), so the
# rule becomes "every rendered figure equals what BOTH platforms would charge".
#
# What it does, per Buy button in public/*.html:
#   1. reads the rendered price from the button text  ("Buy — $39")
#   2. follows the Stripe link's price via the API   (read-only key is enough)
#   3. reads the Shopify variant price from products.json (public, unauthenticated)
#   4. FAIL if any of the three disagree; INCONCLUSIVE if a source cannot be read.
#
# EXIT 0 = PASS. 1 = FAIL. 2 = INCONCLUSIVE (a source was unreachable — that is
# NOT a pass; CLAUDE.md "every guard has three outcomes").
set -uo pipefail
cd "$(dirname "$0")"
FAIL=0; INC=0

# sku|page|shopify_handle|stripe_link_id|stripe_link_url|expected_usd
# Stripe link ids are filled from the manifest written when the links were made.
MANIFEST="stripe-links.psv"
[ -f "$MANIFEST" ] || { echo "INCONCLUSIVE: $MANIFEST missing"; exit 2; }

shop_json=$(curl -sf --max-time 20 "https://shop.zknot.io/products.json?limit=250") || { echo "INCONCLUSIVE: shop.zknot.io/products.json unreachable"; exit 2; }

while IFS='|' read -r sku page shopify_handle link_id link_url expected; do
  [[ "$sku" =~ ^#|^sku ]] && continue
  # 1. rendered
  rendered=$(grep -o "href=\"$link_url\"[^>]*>[^<]*" "public/$page" | grep -o '\$[0-9]*' | tr -d '$' | head -1)
  # 2. stripe — the link's line item price
  stripe_cents=$(stripe get "/v1/payment_links/$link_id/line_items" --live 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(li['price']['unit_amount']*li['quantity'] for li in d['data']))" 2>/dev/null)
  # 3. shopify
  shopify=$(printf '%s' "$shop_json" | python3 -c "
import json,sys; h=sys.argv[1]
for p in json.load(sys.stdin)['products']:
    if p['handle']==h: print(p['variants'][0]['price'].split('.')[0]); break" "$shopify_handle" 2>/dev/null)

  line="$sku: rendered=\$${rendered:-?} stripe=\$$(( ${stripe_cents:-0} / 100 )) shopify=\$${shopify:-n/a} expected=\$$expected"
  if [ -z "$rendered" ] || [ -z "$stripe_cents" ]; then echo "  INCONCLUSIVE $line"; INC=$((INC+1)); continue; fi
  ok=1
  [ "$rendered" = "$expected" ] || ok=0
  [ "$((stripe_cents/100))" = "$expected" ] || ok=0
  if [ "$shopify_handle" != "-" ]; then [ "$shopify" = "$expected" ] || ok=0; fi
  if [ $ok = 1 ]; then echo "  PASS  $line"; else echo "  FAIL  $line"; FAIL=$((FAIL+1)); fi
done < "$MANIFEST"

if [ $FAIL -gt 0 ]; then echo "✗ $FAIL price disagreement(s) — a customer can be charged a figure the site does not show"; exit 1; fi
if [ $INC -gt 0 ]; then echo "? $INC source(s) unreadable — INCONCLUSIVE, not a pass"; exit 2; fi
echo "✓ every rendered price equals what both platforms charge"
