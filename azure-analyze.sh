#!/bin/bash

# Azure Credential Analyzer Script

TENANT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"

if [[ -z "$TENANT_ID" || -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  echo "Usage: $0 <tenant_id> <client_id> <client_secret>"
  exit 1
fi

echo "🔐 Authenticating with Azure..."

TOKEN_RESPONSE=$(curl -s -X POST -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&resource=https://management.azure.com/" \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [[ "$ACCESS_TOKEN" == "null" || -z "$ACCESS_TOKEN" ]]; then
  echo "❌ Failed to authenticate. Invalid credentials."
  exit 1
fi

echo "✅ Authentication successful!"

echo -e "\n🔎 Fetching subscription details..."
SUBSCRIPTIONS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" \
  "https://management.azure.com/subscriptions?api-version=2020-01-01")

SUB_COUNT=$(echo "$SUBSCRIPTIONS" | jq '.value | length')

if [[ "$SUB_COUNT" -eq 0 ]]; then
  echo "⚠️ No subscriptions found or insufficient access."
else
  echo "📄 Found $SUB_COUNT subscription(s):"
  echo "$SUBSCRIPTIONS" | jq -r '.value[] | "🔹 Subscription: \(.displayName) [\(.subscriptionId)]"'
fi

echo -e "\n🔐 Checking role assignments in each subscription..."

echo "$SUBSCRIPTIONS" | jq -r '.value[].subscriptionId' | while read -r SUB_ID; do
  echo -e "\n🔸 Subscription ID: $SUB_ID"
  ROLES=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://management.azure.com/subscriptions/${SUB_ID}/providers/Microsoft.Authorization/roleAssignments?api-version=2020-04-01-preview")

  ROLE_COUNT=$(echo "$ROLES" | jq '.value | length')
  if [[ "$ROLE_COUNT" -eq 0 ]]; then
    echo "   🔒 No role assignments found (or insufficient permission to view)."
  else
    echo "$ROLES" | jq -r '.value[] | "   ✅ Role Assignment: \(.properties.roleDefinitionId)"'
  fi
done

echo -e "\n✅ Analysis Complete!"
