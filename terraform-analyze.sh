#!/bin/bash

TOKEN=$1

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <TFC_PERSONAL_TOKEN>"
  exit 1
fi

HEADER="Authorization: Bearer $TOKEN"
API="https://app.terraform.io/api/v2"

# ─────────────────────────────────────────────────────────────
echo "🔍 Fetching user details..."
user=$(curl -s -H "$HEADER" "$API/account/details")
username=$(echo "$user" | jq -r '.data.attributes.username')
email=$(echo "$user" | jq -r '.data.attributes.email')
admin=$(echo "$user" | jq -r '.data.attributes.["is-admin"]')
can_create_orgs=$(echo "$user" | jq -r '.data.attributes.permissions["can-create-organizations"]')
tfa_enabled=$(echo "$user" | jq -r '.data.attributes["two-factor"].enabled')

echo "👤 User: $username <$email>"
echo "🔐 2FA Enabled: $tfa_enabled"
echo "🛠️ Admin: $admin | Can Create Orgs: $can_create_orgs"
echo

# ─────────────────────────────────────────────────────────────
echo "🏢 Fetching organizations..."
orgs=$(curl -s -H "$HEADER" "$API/organizations")

if [[ $(echo "$orgs" | jq '.data | length') -eq 0 ]]; then
  echo "❌ No organizations found."
  exit 0
fi

for org in $(echo "$orgs" | jq -r '.data[].id'); do
  echo "🔸 Organization: $org"

  echo "  👥 Teams:"
  teams=$(curl -s -H "$HEADER" "$API/organizations/$org/teams")

  for team in $(echo "$teams" | jq -c '.data[]'); do
    team_id=$(echo "$team" | jq -r '.id')
    team_name=$(echo "$team" | jq -r '.attributes.name')
    echo "    • Team: $team_name ($team_id)"

    members=$(curl -s -H "$HEADER" "$API/teams/$team_id/team-memberships")
    for uid in $(echo "$members" | jq -r '.data[].relationships.user.data.id'); do
      u=$(curl -s -H "$HEADER" "$API/users/$uid")
      uname=$(echo "$u" | jq -r '.data.attributes.username')
      uemail=$(echo "$u" | jq -r '.data.attributes.email')
      echo "        - $uname <$uemail>"
    done
  done

  echo "  🗂️ Workspaces:"
  workspaces=$(curl -s -H "$HEADER" "$API/organizations/$org/workspaces")
  for ws in $(echo "$workspaces" | jq -c '.data[]'); do
    ws_id=$(echo "$ws" | jq -r '.id')
    ws_name=$(echo "$ws" | jq -r '.attributes.name')
    echo "    • Workspace: $ws_name ($ws_id)"

    # Optionally list variables, runs, access, etc. per workspace
  done

  echo
done

# ─────────────────────────────────────────────────────────────
echo "🔗 Auth Tokens and Linked Resources:"
tokens_url=$(echo "$user" | jq -r '.data.relationships."authentication-tokens".links.related')
tokens=$(curl -s -H "$HEADER" "$API$tokens_url")
echo "$tokens" | jq -r '.data[] | "  • Token created at: \(.attributes."created-at") | ID: \(.id)"'

echo
