#!/usr/bin/env bash
# check-price-sources.sh — one price per SKU across zknot.io and Stripe.
#
# 2026-10-22: Shopify retired (operator ruling). Stripe is the only platform that
# charges; the Shopify fetch is removed so a closed store cannot turn every run
# INCONCLUSIVE. The shopify_handle column stays in the manifest, all "-".
#
# CATALOG-SSOT-001 §0.3: one platform object per SKU is the charging authority.
# From 2026-09-18 two platforms charge for the same articles (operator ruling,
# session 2026-09-18: Stripe Payment Links on zknot.io AND shop.zknot.io), so the
# rule becomes "every rendered figure equals what BOTH platforms would charge".
#
# What it does, per Buy button in public/*.html:
#   1. reads the rendered price from the button text  ("Buy — $39")
#   2. follows the Stripe link's price via the API   (read-only key is enough)
#   3. FAIL if the rendered, Stripe and expected prices disagree; INCONCLUSIVE if a source cannot be read.
#
# EXIT 0 = PASS. 1 = FAIL. 2 = INCONCLUSIVE (a source was unreachable — that is
# NOT a pass; CLAUDE.md "every guard has three outcomes").
set -uo pipefail
cd "$(dirname "$0")"
FAIL=0; INC=0

# sku|page|shopify_handle|stripe_link_id|stripe_link_url|expected_usd
# shopify_handle may be "handle#Variant title" to check one variant of a multi-variant
# listing; a bare handle checks the first variant.
# Stripe link ids are filled from the manifest written when the links were made.
MANIFEST="stripe-links.psv"
[ -f "$MANIFEST" ] || { echo "INCONCLUSIVE: $MANIFEST missing"; exit 2; }


while IFS='|' read -r sku page shopify_handle link_id link_url expected; do
  [[ "$sku" =~ ^#|^sku ]] && continue
  # 1. rendered
  rendered=$(grep -o "href=\"$link_url\"[^>]*>[^<]*" "public/$page" | grep -o '\$[0-9]*' | tr -d '$' | head -1)
  # 2. stripe — the link's line item price
  stripe_cents=$(stripe get "/v1/payment_links/$link_id/line_items" --live 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(li['price']['unit_amount']*li['quantity'] for li in d['data']))" 2>/dev/null)

  line="$sku: rendered=\$${rendered:-?} stripe=\$$(( ${stripe_cents:-0} / 100 )) expected=\$$expected"
  if [ -z "$rendered" ] || [ -z "$stripe_cents" ]; then echo "  INCONCLUSIVE $line"; INC=$((INC+1)); continue; fi
  ok=1
  [ "$rendered" = "$expected" ] || ok=0
  [ "$((stripe_cents/100))" = "$expected" ] || ok=0
  if [ $ok = 1 ]; then echo "  PASS  $line"; else echo "  FAIL  $line"; FAIL=$((FAIL+1)); fi
done < "$MANIFEST"

# The /shop overview repeats every price as data-sku="SKU">$N, with no Buy button.
# Each figure must equal `expected`, and every SKU in the manifest must appear there,
# so an offering can't be added to the site without reaching the shop page.
SHOP="public/shop.html"
if [ ! -f "$SHOP" ]; then echo "  INCONCLUSIVE shop: $SHOP missing"; INC=$((INC+1)); else
while IFS='|' read -r sku page shopify_handle link_id link_url expected; do
  [[ "$sku" =~ ^#|^sku ]] && continue
  shown=$(grep -o "data-sku=\"$sku\">\\\$[0-9]*" "$SHOP" | grep -o '[0-9]*$' | sort -u)
  if [ -z "$shown" ]; then echo "  FAIL  shop: $sku not listed on /shop"; FAIL=$((FAIL+1))
  elif [ "$shown" != "$expected" ]; then echo "  FAIL  shop: $sku shows \$$(echo $shown) expected=\$$expected"; FAIL=$((FAIL+1))
  else echo "  PASS  shop: $sku \$$shown"; fi
done < "$MANIFEST"
for sku in $(grep -o 'data-sku="[^"]*"' "$SHOP" | cut -d'"' -f2 | sort -u); do
  grep -q "^$sku|" "$MANIFEST" || { echo "  FAIL  shop: data-sku=$sku is not in $MANIFEST"; FAIL=$((FAIL+1)); }
done
fi

if [ $FAIL -gt 0 ]; then echo "✗ $FAIL price disagreement(s) — a customer can be charged a figure the site does not show"; exit 1; fi
if [ $INC -gt 0 ]; then echo "? $INC source(s) unreadable — INCONCLUSIVE, not a pass"; exit 2; fi
echo "✓ every rendered price equals what Stripe charges"
