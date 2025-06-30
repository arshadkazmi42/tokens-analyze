#!/usr/bin/env bash

# --- Check Dependencies ---
if ! command -v jq >/dev/null; then
  echo "❌ Please install jq first (https://stedolan.github.io/jq/)"
  exit 1
fi

# --- Usage ---
if [ $# -lt 1 ]; then
  echo "Usage: $0 <token> [base_url]"
  echo "Example: $0 sgpat_xxxx https://sourcegraph.com"
  exit 1
fi

TOKEN="$1"
BASE_URL="${2:-https://sourcegraph.com}"  # default to public cloud

GRAPHQL="$BASE_URL/.api/graphql"

# --- Helper to Run Queries ---
function graphql_query() {
  local QUERY="$1"
  curl -s -X POST "$GRAPHQL" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $TOKEN" \
    -d "{\"query\": \"$QUERY\"}"
}

echo "🔍 Verifying Sourcegraph token against $BASE_URL"

# --- Current User Info ---
USER_RES=$(graphql_query 'query { currentUser { id username displayName emails { email } siteAdmin } }')

USER_ID=$(echo "$USER_RES" | jq -r '.data.currentUser.id // empty')
USERNAME=$(echo "$USER_RES" | jq -r '.data.currentUser.username // empty')
EMAIL=$(echo "$USER_RES" | jq -r '.data.currentUser.emails[0].email // empty')
ADMIN=$(echo "$USER_RES" | jq -r '.data.currentUser.siteAdmin // empty')

if [[ -z "$USER_ID" ]]; then
  echo "❌ Token is invalid or has no access"
  exit 1
fi

echo ""
echo "✅ Authenticated as:"
printf "  Username : %s\n" "$USERNAME"
printf "  Email    : %s\n" "$EMAIL"
printf "  User ID  : %s\n" "$USER_ID"
printf "  Admin    : %s\n" "$ADMIN"

# --- Org Info ---
ORG_RES=$(graphql_query 'query { organizations { nodes { id name displayName members { nodes { username email } } } } }')

ORG_COUNT=$(echo "$ORG_RES" | jq '.data.organizations.nodes | length')

if [[ "$ORG_COUNT" -eq 0 ]]; then
  echo -e "\n📦 No organizations accessible"
else
  echo -e "\n🏢 Organizations found: $ORG_COUNT"
  echo "$ORG_RES" | jq -r '
    .data.organizations.nodes[] as $org |
    "Org: \($org.name) (\($org.displayName))\n  ID: \($org.id)\n  Members:" +
    ( $org.members.nodes | map("    \(.username) <\(.email)>") | join("\n") )
  '
fi

# --- Summary for Bug Bounty ---
echo -e "\n🛡️  Suggested Disclosure Note:"
cat <<EOF

This Sourcegraph access token is valid and allows:
- User enumeration (username, email, user ID)
- Organization name and ID enumeration
- Org membership discovery (usernames/emails)
- Site admin status of authenticated user

✅ Read-only access confirmed.
❌ No write or mutation actions were tested.

EOF
