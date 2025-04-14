#!/bin/bash

APP_ID=$1
API_KEY=$2

if [[ -z "$APP_ID" || -z "$API_KEY" ]]; then
  echo "Usage: $0 <APP_ID> <API_KEY>"
  exit 1
fi

echo "🔍 Fetching key details..."
KEY_DETAILS=$(curl -s "https://$APP_ID.algolia.net/1/keys/$API_KEY" \
  -H "accept: application/json" \
  -H "x-algolia-api-key: $API_KEY" \
  -H "x-algolia-application-id: $APP_ID")

if [[ -z "$KEY_DETAILS" ]]; then
  echo "❌ No key details found. Make sure the key is valid."
  exit 1
fi

# Parse ACLs
ACL=$(echo "$KEY_DETAILS" | jq -r '.acl[]' | paste -sd "," -)
DESCRIPTION=$(echo "$KEY_DETAILS" | jq -r '.description // "N/A"')
INDEXES=$(echo "$KEY_DETAILS" | jq -r '.indexes[]' 2>/dev/null | paste -sd "," -)
INDEXES=${INDEXES:-"*"}
QUERIES_PER_HOUR=$(echo "$KEY_DETAILS" | jq -r '.maxQueriesPerIPPerHour // "Unlimited"')
HITS_PER_QUERY=$(echo "$KEY_DETAILS" | jq -r '.maxHitsPerQuery // "Unlimited"')
VALIDITY=$(echo "$KEY_DETAILS" | jq -r '.validity')
VALIDITY_READABLE=$([[ "$VALIDITY" == "0" ]] && echo "Never expires" || echo "$VALIDITY seconds")
CREATED_AT=$(echo "$KEY_DETAILS" | jq -r '.createdAt')

# Permission checks
has_acl() {
  echo "$ACL" | grep -q "$1"
}

echo -e "\n🔐 Algolia API Key Access Report"
echo "----------------------------------"
echo "🔸 Description     : $DESCRIPTION"
echo "🔸 Index Scope     : $INDEXES"
echo "🔸 Created At      : $CREATED_AT"
echo "🔸 Validity        : $VALIDITY_READABLE"
echo "🔸 Rate Limit      : $QUERIES_PER_HOUR QPH/IP | $HITS_PER_QUERY hits/query"
echo ""
echo "📋 Access Flags:"
printf " - Search Access  : %s\n" $(has_acl "search" && echo "✅" || echo "❌")
printf " - Write Access   : %s\n" $(echo "$ACL" | grep -Eq 'addObject|deleteObject|editSettings|deleteIndex' && echo "✅" || echo "❌")
printf " - Admin Access   : %s\n" $(echo "$INDEXES" | grep -q "*" && echo "✅" || echo "❌")
printf " - Analytics       : %s\n" $(has_acl "analytics" && echo "✅" || echo "❌")
printf " - Logs Access     : %s\n" $(has_acl "logs" && echo "✅" || echo "❌")
echo ""
