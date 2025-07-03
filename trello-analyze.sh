#!/bin/bash

# Usage: ./analyze_trello.sh YOUR_API_KEY YOUR_TOKEN

API_KEY="$1"
API_TOKEN="$2"

if [[ -z "$API_KEY" || -z "$API_TOKEN" ]]; then
  echo "Usage: $0 <API_KEY> <TOKEN>"
  exit 1
fi

echo "🔍 Verifying credentials..."
ME_URL="https://api.trello.com/1/members/me?key=${API_KEY}&token=${API_TOKEN}"
ME_JSON=$(curl -s "$ME_URL")

USERNAME=$(echo "$ME_JSON" | jq -r '.username')
FULLNAME=$(echo "$ME_JSON" | jq -r '.fullName')
EMAIL=$(echo "$ME_JSON" | jq -r '.email // "N/A"')
ID_MEMBER=$(echo "$ME_JSON" | jq -r '.id')

echo "✅ Authenticated as: $FULLNAME (@$USERNAME)"
echo "📧 Email: $EMAIL"
echo "🆔 Trello Member ID: $ID_MEMBER"
echo

echo "🏢 Fetching organizations (workspaces)..."
ORG_URL="https://api.trello.com/1/members/me/organizations?key=${API_KEY}&token=${API_TOKEN}"
ORG_JSON=$(curl -s "$ORG_URL")

ORG_COUNT=$(echo "$ORG_JSON" | jq 'length')
if [[ "$ORG_COUNT" -eq 0 ]]; then
  echo "No organizations found or access denied."
  exit 0
fi

for (( i=0; i<ORG_COUNT; i++ )); do
  ORG_ID=$(echo "$ORG_JSON" | jq -r ".[$i].id")
  ORG_NAME=$(echo "$ORG_JSON" | jq -r ".[$i].name")
  ORG_DISPLAY=$(echo "$ORG_JSON" | jq -r ".[$i].displayName")
  ORG_DESC=$(echo "$ORG_JSON" | jq -r ".[$i].desc")
  echo "-------------------------------------------"
  echo "🏢 Workspace: $ORG_DISPLAY ($ORG_NAME)"
  echo "📝 Description: ${ORG_DESC:-N/A}"

  echo "👥 Members:"
  curl -s "https://api.trello.com/1/organizations/${ORG_ID}/members?key=${API_KEY}&token=${API_TOKEN}" \
    | jq -r '.[] | " - \(.fullName) (@\(.username)) [\(.memberType)]"'

  echo "📋 Boards:"
  curl -s "https://api.trello.com/1/organizations/${ORG_ID}/boards?key=${API_KEY}&token=${API_TOKEN}" \
    | jq -r '.[] | " - \(.name) [\(.id)] (\(.prefs.permissionLevel))"'

  echo
done
