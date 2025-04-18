#!/bin/bash
# Usage: ./bitly_analyzer.sh <bitly_token>
TOKEN="$1"
if [ -z "$TOKEN" ]; then
  echo "❌ Please provide a Bitly token as the first argument."
  exit 1
fi
echo "🔍 Validating token and fetching user info..."
# Fetch all required details
USER_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" https://api-ssl.bitly.com/v4/user)
GROUPS_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" https://api-ssl.bitly.com/v4/groups)
USERNAME=$(echo "$USER_RESPONSE" | jq -r '.name // "Unknown"')
DEFAULT_GROUP_GUID=$(echo "$USER_RESPONSE" | jq -r '.default_group_guid // "Unknown"')
echo ""
echo "👤 User Info"
echo "----------------------------------------"
echo "Username       : $USERNAME"
echo "Default Group  : $DEFAULT_GROUP_GUID"
echo ""
echo "📧 Email Addresses"
echo "----------------------------------------"
# Draw a table header with separators
printf "%-30s | %-10s | %-10s\n" "Email" "Primary" "Verified"
printf "%s\n" "------------------------------+------------+------------"
# Process email data directly from USER_RESPONSE instead of EMAILS_RESPONSE
echo "$USER_RESPONSE" | jq -r '.emails[]? | "\(.email)\t\(.is_primary)\t\(.is_verified)"' | while IFS=$'\t' read -r email primary verified; do
  printf "%-30s | %-10s | %-10s\n" "$email" "$primary" "$verified"
done
echo ""
echo "🏢 Organization / Group Info"
echo "----------------------------------------"
echo "$GROUPS_RESPONSE" | jq -r '
.groups[]? |
"🔹 Group: \(.name)
    ↳ GUID           : \(.guid)
    ↳ Organization   : \(.organization.name // "N/A")
    ↳ Role           : \(.role // "Unknown")"
'
echo ""
echo "🔗 Fetching shortened URLs (recent activity)..."
LINKS_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" "https://api-ssl.bitly.com/v4/groups/$DEFAULT_GROUP_GUID/bitlinks")
LINKS_COUNT=$(echo "$LINKS_RESPONSE" | jq '.links | length')
if [[ "$LINKS_COUNT" -gt 0 ]]; then
  echo ""
  # Draw a table header with separators for links
  printf "%-30s | %-60s | %-25s\n" "Title" "Short URL" "Created At"
  printf "%s\n" "------------------------------+--------------------------------------------------------------+---------------------------"
  # Process links data and format as a table
  echo "$LINKS_RESPONSE" | jq -r '.links[] | "\(.title // "N/A")\t\(.link)\t\(.created_at)"' | while IFS=$'\t' read -r title link created; do
    printf "%-30s | %-60s | %-25s\n" "$title" "$link" "$created"
  done
else
  echo "No shortened URLs found."
fi
echo ""
echo "✅ Access and Activity Analysis Complete"
