#!/bin/bash

API_TOKEN=$1
if [[ -z "$API_TOKEN" ]]; then
  echo "Usage: $0 <API_TOKEN>"
  exit 1
fi

echo "🔍 Fetching Crowdin account details..."

# Fetch user details
USER_DETAILS=$(curl -s "https://api.crowdin.com/api/v2/user" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

if [[ -z "$USER_DETAILS" ]]; then
  echo "❌ Failed to fetch user details. Make sure the token is valid."
  exit 1
fi

# Fetch organization details
ORG_DETAILS=$(curl -s "https://api.crowdin.com/api/v2/organizations" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

# Parse user details
USERNAME=$(echo "$USER_DETAILS" | jq -r '.data.username // "N/A"')
EMAIL=$(echo "$USER_DETAILS" | jq -r '.data.email // "N/A"')
JOIN_DATE=$(echo "$USER_DETAILS" | jq -r '.data.createdAt // "N/A"')
TIMEZONE=$(echo "$USER_DETAILS" | jq -r '.data.timezone // "N/A"')

# Parse organization details
ORG_NAME=$(echo "$ORG_DETAILS" | jq -r '.data[0].name // "N/A"')
ORG_ROLE=$(echo "$ORG_DETAILS" | jq -r '.data[0].role // "N/A"')

# Fetch projects
PROJECTS=$(curl -s "https://api.crowdin.com/api/v2/projects" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json")

# Count accessible projects
PROJECT_COUNT=$(echo "$PROJECTS" | jq '.data | length')

echo -e "\n👤 Crowdin Account Analysis Report"
echo "----------------------------------"
echo "🔸 Username        : $USERNAME"
echo "🔸 Email           : $EMAIL"
echo "🔸 Join Date       : $JOIN_DATE"
echo "🔸 Timezone        : $TIMEZONE"
echo "🔸 Organization    : $ORG_NAME"
echo "🔸 Org Role        : $ORG_ROLE"
echo "🔸 Accessible Projects: $PROJECT_COUNT"

echo -e "\n📋 Access Details:"
echo "----------------------------------"

# Check API access levels
check_access() {
  local endpoint=$1
  local response=$(curl -s -o /dev/null -w "%{http_code}" "https://api.crowdin.com/api/v2/$endpoint" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")
  [[ "$response" == "200" ]] && echo "✅" || echo "❌"
}

printf " - Project Management : %s\n" $(check_access "projects")
printf " - File Management   : %s\n" $(check_access "storages")
printf " - Translation Access: %s\n" $(check_access "translations")
printf " - User Management   : %s\n" $(check_access "users")
printf " - Reports Access    : %s\n" $(check_access "reports")

echo -e "\n📊 Project Overview:"
echo "----------------------------------"
if [[ $PROJECT_COUNT -gt 0 ]]; then
  echo "$PROJECTS" | jq -r '.data[] | " - \(.data.name) (\(.data.identifier))"' 2>/dev/null
else
  echo "No projects accessible"
fi

echo "" 