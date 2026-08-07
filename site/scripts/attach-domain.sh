#!/usr/bin/env bash
# Point a domain at the Chronograph Cloudflare Pages project.
#
#   ./site/scripts/attach-domain.sh [domain] [pages-project]
#   defaults: chronograph.fyi  chronograph-page
#
# Does two things:
#   1. Cloudflare — registers the domain as a custom domain on the Pages project
#   2. Porkbun    — creates the apex ALIAS record pointing at <project>.pages.dev
#
# Secrets are read from 1Password at runtime and never written to disk, echoed,
# or committed. Required items (Employee vault, account geist@artifact.com):
#
#   "Cloudflare API token chronograph"    credential = the API token
#   "Porkbun API"                        username   = API key      (pk1_...)
#                                        credential = secret key   (sk1_...)
#
# Cloudflare token needs: Account > Cloudflare Pages > Edit
# Porkbun needs API access enabled on the domain itself (see site/README.md).
set -euo pipefail

DOMAIN="${1:-chronograph.fyi}"
PROJECT="${2:-chronograph-page}"
ACCOUNT_ID="c0912e10eadeaa117b0067ab29b55da6"   # Artifact
TARGET="$PROJECT.pages.dev"
export OP_ACCOUNT="${OP_ACCOUNT:-arfct.1password.com}"

need() { command -v "$1" >/dev/null || { echo "error: $1 not installed" >&2; exit 1; }; }
need op; need curl; need python3

json() { python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d))'; }
ok()   { python3 -c 'import json,sys; print("yes" if json.load(sys.stdin).get("success") else "no")'; }
errs() { python3 -c 'import json,sys; [print("   -",e.get("message",e)) for e in json.load(sys.stdin).get("errors",[])]'; }

echo "domain:  $DOMAIN"
echo "project: $PROJECT  ->  $TARGET"
echo

# ---------------------------------------------------------------- Cloudflare
CF_TOKEN="$(op read "op://Employee/Cloudflare API token chronograph/credential")"
[ -n "$CF_TOKEN" ] || { echo "error: empty Cloudflare token from 1Password" >&2; exit 1; }

echo "==> Cloudflare: verifying token"
RESP=$(curl -sS -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/user/tokens/verify")
if [ "$(printf '%s' "$RESP" | ok)" != "yes" ]; then
  echo "   token verify failed:"; printf '%s' "$RESP" | errs; exit 1
fi
echo "   token valid"

CF_API="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/pages/projects/$PROJECT/domains"

echo "==> Cloudflare: existing custom domains"
EXISTING=$(curl -sS -H "Authorization: Bearer $CF_TOKEN" "$CF_API" \
  | python3 -c 'import json,sys; print(" ".join(d["name"] for d in json.load(sys.stdin).get("result") or []))')
echo "   ${EXISTING:-(none)}"

if printf '%s' "$EXISTING" | tr ' ' '\n' | grep -qx "$DOMAIN"; then
  echo "   $DOMAIN already attached — skipping"
else
  echo "==> Cloudflare: attaching $DOMAIN"
  RESP=$(curl -sS -X POST -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" --data "{\"name\":\"$DOMAIN\"}" "$CF_API")
  if [ "$(printf '%s' "$RESP" | ok)" = "yes" ]; then
    echo "   attached"
  else
    echo "   attach failed:"; printf '%s' "$RESP" | errs; exit 1
  fi
fi

# ------------------------------------------------------------------- Porkbun
PB_KEY="$(op read "op://Employee/Porkbun API/username")"
PB_SECRET="$(op read "op://Employee/Porkbun API/credential")"
[ -n "$PB_KEY" ] && [ -n "$PB_SECRET" ] || { echo "error: empty Porkbun creds" >&2; exit 1; }

PB="https://api.porkbun.com/api/json/v3"
auth() { printf '{"apikey":"%s","secretapikey":"%s"%s}' "$PB_KEY" "$PB_SECRET" "${1:-}"; }

echo
echo "==> Porkbun: ping"
RESP=$(curl -sS -X POST -H "Content-Type: application/json" -d "$(auth)" "$PB/ping")
STATUS=$(printf '%s' "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))')
if [ "$STATUS" != "SUCCESS" ]; then
  echo "   ping failed: $(printf '%s' "$RESP" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("message","?"))')"
  exit 1
fi
echo "   authenticated"

echo "==> Porkbun: existing apex records"
RESP=$(curl -sS -X POST -H "Content-Type: application/json" -d "$(auth)" "$PB/dns/retrieve/$DOMAIN")
printf '%s' "$RESP" | python3 -c '
import json,sys
d = json.load(sys.stdin)
if d.get("status") != "SUCCESS":
    print("   retrieve failed:", d.get("message","?")); sys.exit(1)
rows = [r for r in d.get("records", []) if r["name"] in (sys.argv[1], "")]
for r in rows or []:
    print("   %-6s %-24s %s  (id %s)" % (r["type"], r["name"], r["content"], r["id"]))
if not rows: print("   (none)")
' "$DOMAIN"

APEX_ALIAS=$(printf '%s' "$RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in d.get('records',[]):
    if r['name']=='$DOMAIN' and r['type']=='ALIAS': print(r['id']); break
")

if [ -n "$APEX_ALIAS" ]; then
  echo "==> Porkbun: updating existing ALIAS (id $APEX_ALIAS) -> $TARGET"
  RESP=$(curl -sS -X POST -H "Content-Type: application/json" \
    -d "$(auth ",\"name\":\"\",\"type\":\"ALIAS\",\"content\":\"$TARGET\",\"ttl\":\"600\"")" \
    "$PB/dns/edit/$DOMAIN/$APEX_ALIAS")
else
  echo "==> Porkbun: creating apex ALIAS -> $TARGET"
  RESP=$(curl -sS -X POST -H "Content-Type: application/json" \
    -d "$(auth ",\"name\":\"\",\"type\":\"ALIAS\",\"content\":\"$TARGET\",\"ttl\":\"600\"")" \
    "$PB/dns/create/$DOMAIN")
fi
printf '%s' "$RESP" | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("   " + ("ok" if d.get("status")=="SUCCESS" else "failed: " + str(d.get("message"))))
sys.exit(0 if d.get("status")=="SUCCESS" else 1)'

cat <<EOF

Done. Cloudflare still has to validate the domain and issue a certificate,
which usually takes a couple of minutes. Verify with:

  dig +short $DOMAIN
  curl -sSI https://$DOMAIN | grep -i location      # expect 302 -> TestFlight
  curl -sS -o /dev/null -w '%{http_code}\\n' https://$DOMAIN/privacy   # expect 200
EOF
