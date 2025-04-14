#!/bin/bash

# Usage: ./mandrill_access_report.sh YOUR_API_KEY

API_KEY="$1"
if [[ -z "$API_KEY" ]]; then
  echo "❌ Error: API key not provided."
  echo "Usage: $0 <MANDRILL_API_KEY>"
  exit 1
fi

BASE_URL="https://mandrillapp.com/api/1.0"
HEADERS="-H Content-Type:application/json"
PAYLOAD="{\"key\":\"$API_KEY\"}"

echo "🔍 Generating Mandrill Access Level Report..."
echo "============================================"
echo

# Function to test API call and return whether it worked
check_access() {
  local endpoint="$1"
  local label="$2"
  local response
  response=$(curl -s -X POST "$BASE_URL/$endpoint" $HEADERS -d "$PAYLOAD")

  if echo "$response" | grep -q "\"status\":\"error\""; then
    echo "❌ $label: No Access"
  else
    echo "✅ $label: Accessible"
  fi
}

# User Info
echo "🔐 User Identity:"
USER_RESPONSE=$(curl -s -X POST "$BASE_URL/users/info.json" $HEADERS -d "$PAYLOAD")

if echo "$USER_RESPONSE" | grep -q "\"username\""; then
  echo "$USER_RESPONSE" | jq '{Email: .username, CreatedAt: .created_at, Reputation: .reputation, HourlyQuota: .hourly_quota}'
else
  echo "❌ Failed to fetch user info. Invalid or restricted key."
  exit 1
fi

echo
echo "🔎 API Access Overview:"
echo "--------------------------------------------"
check_access "messages/send.json" "Send Email"
check_access "messages/search.json" "Search Email History"
check_access "inbound/domains.json" "Inbound Domains"
check_access "users/senders.json" "Sender Info"
check_access "templates/list.json" "Templates"
check_access "subaccounts/list.json" "Subaccounts"
check_access "tags/list.json" "Tags"
check_access "rejects/list.json" "Reject List"
check_access "whitelists/list.json" "Whitelisted Emails"

echo
echo "✅ Report complete."
