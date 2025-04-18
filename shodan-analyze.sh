#!/bin/bash

# Usage: ./shodan_analyzer_extended.sh <shodan_api_key>
KEY="$1"

if [ -z "$KEY" ]; then
  echo "❌ Please provide a Shodan API key."
  exit 1
fi

echo "🔍 Validating and extracting user/org info..."

# 1. Account Profile
ACCOUNT_JSON=$(curl -s "https://api.shodan.io/account/profile?key=$KEY")

if [[ "$ACCOUNT_JSON" == *"error"* ]]; then
  echo "❌ Invalid or expired API key."
  exit 1
fi

EMAIL=$(echo "$ACCOUNT_JSON" | jq -r '.email // "N/A"')
DISPLAY_NAME=$(echo "$ACCOUNT_JSON" | jq -r '.display_name // "N/A"')
CREDITS=$(echo "$ACCOUNT_JSON" | jq -r '.credits // "N/A"')
CREATED=$(echo "$ACCOUNT_JSON" | jq -r '.created // "N/A"')
MEMBER=$(echo "$ACCOUNT_JSON" | jq -r '.member')
TWOFA=$(echo "$ACCOUNT_JSON" | jq -r '.two_factor')
VERIFIED=$(echo "$ACCOUNT_JSON" | jq -r '.verified')

# 2. API Info - Plan Details
API_INFO=$(curl -s "https://api.shodan.io/api-info?key=$KEY")
PLAN_NAME=$(echo "$API_INFO" | jq -r '.plan // "N/A"')
SCAN_LIMIT=$(echo "$API_INFO" | jq -r '.scan_credits // "N/A"')

# 3. Alerts - Monitored Networks
ALERTS=$(curl -s "https://api.shodan.io/shodan/alert/info?key=$KEY")

echo ""
echo "👤 Shodan Account Info"
echo "----------------------------------------"
printf "Name / Org        : %s\n" "$DISPLAY_NAME"
printf "Email             : %s\n" "$EMAIL"
printf "Email Verified    : %s\n" "$VERIFIED"
printf "2FA Enabled       : %s\n" "$TWOFA"
printf "Account Created   : %s\n" "$CREATED"
printf "Paid Member       : %s\n" "$MEMBER"

echo ""
echo "📦 Plan Details"
echo "----------------------------------------"
printf "Plan Name         : %s\n" "$PLAN_NAME"
printf "Scan Credits Left : %s\n" "$SCAN_LIMIT"

echo ""
echo "🧠 Monitored Networks (Alerts)"
echo "----------------------------------------"

echo "$ALERTS" | jq -r '
.[] | 
"• Alert Name: \(.name)
  ↳ IP Filter : \(.filters.ip)
  ↳ Created   : \(.created)"
'

echo ""
echo "✅ Extended Analysis Complete"
