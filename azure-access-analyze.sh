#!/bin/bash

# --- Inputs ---
read -p "Enter Client ID: " CLIENT_ID
read -p "Enter Client Secret: " CLIENT_SECRET
read -p "Enter Tenant ID: " TENANT_ID

# --- Functions ---
fetch_token() {
  local scope=$1
  curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=$scope" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "grant_type=client_credentials"
}

test_api() {
  local token=$1
  local url=$2
  local desc=$3

  response=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$url" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json")

  if [ "$response" == "200" ]; then
    echo "[OK] $desc"
  else
    echo "[FAIL] $desc (HTTP $response)"
  fi
}

# --- Fetch Tokens ---
echo "Fetching Graph API Token..."
GRAPH_TOKEN_RESPONSE=$(fetch_token "https://graph.microsoft.com/.default")
GRAPH_ACCESS_TOKEN=$(echo "$GRAPH_TOKEN_RESPONSE" | jq -r '.access_token')

echo "Fetching Azure Management Token..."
MGMT_TOKEN_RESPONSE=$(fetch_token "https://management.azure.com/.default")
MGMT_ACCESS_TOKEN=$(echo "$MGMT_TOKEN_RESPONSE" | jq -r '.access_token')

# --- Validate Tokens ---
if [[ "$GRAPH_ACCESS_TOKEN" == "null" || -z "$GRAPH_ACCESS_TOKEN" ]]; then
  echo "Error fetching Graph token:"
  echo "$GRAPH_TOKEN_RESPONSE"
  exit 1
fi

if [[ "$MGMT_ACCESS_TOKEN" == "null" || -z "$MGMT_ACCESS_TOKEN" ]]; then
  echo "Error fetching Management token:"
  echo "$MGMT_TOKEN_RESPONSE"
  exit 1
fi

# --- Test APIs ---

echo ""
echo "========== Testing Access =========="

# Microsoft Graph Tests
test_api "$GRAPH_ACCESS_TOKEN" "https://graph.microsoft.com/v1.0/organization" "Organization Info"
test_api "$GRAPH_ACCESS_TOKEN" "https://graph.microsoft.com/v1.0/users" "List Users"
test_api "$GRAPH_ACCESS_TOKEN" "https://graph.microsoft.com/v1.0/domains" "List Domains"

# Azure Management Tests
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions?api-version=2020-01-01" "List Subscriptions"
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourcegroups?api-version=2021-04-01" "List Resource Groups"
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resources?api-version=2021-04-01" "List Resources"
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Storage/storageAccounts?api-version=2021-04-01" "List Storage Accounts"
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Compute/virtualMachines?api-version=2021-07-01" "List Virtual Machines"
test_api "$MGMT_ACCESS_TOKEN" "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Sql/servers?api-version=2021-02-01-preview" "List SQL Servers"

echo "======================================"
echo "Done!"
