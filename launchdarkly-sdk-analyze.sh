#!/bin/bash

SDK_KEY=$1
if [[ -z "$SDK_KEY" ]]; then
  echo "Usage: $0 <SDK_KEY>"
  exit 1
fi

echo "🔍 Analyzing LaunchDarkly SDK access..."

# Function to make API requests
make_request() {
  local endpoint=$1
  curl -s "https://app.launchdarkly.com/api/v2/$endpoint" \
    -H "Authorization: $SDK_KEY" \
    -H "Content-Type: application/json"
}

# Fetch identity details
IDENTITY=$(make_request "caller-identity")

if [[ -z "$IDENTITY" ]]; then
  echo "❌ Failed to fetch identity details. Make sure the SDK key is valid."
  exit 1
fi

# Check for error response
if echo "$IDENTITY" | jq -e '.code' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$IDENTITY" | jq -r '.message // "Unknown error"')
  echo "❌ API Error: $ERROR_MSG"
  exit 1
fi

# Parse identity details
ACCOUNT_ID=$(echo "$IDENTITY" | jq -r '.accountId // "N/A"')
ENV_ID=$(echo "$IDENTITY" | jq -r '.environmentId // "N/A"')
PROJECT_ID=$(echo "$IDENTITY" | jq -r '.projectId // "N/A"')
ENV_NAME=$(echo "$IDENTITY" | jq -r '.environmentName // "N/A"')
PROJECT_NAME=$(echo "$IDENTITY" | jq -r '.projectName // "N/A"')
AUTH_KIND=$(echo "$IDENTITY" | jq -r '.authKind // "N/A"')
TOKEN_KIND=$(echo "$IDENTITY" | jq -r '.tokenKind // "N/A"')
SERVICE_TOKEN=$(echo "$IDENTITY" | jq -r '.serviceToken // "N/A"')

echo -e "\n🎯 LaunchDarkly SDK Analysis Report"
echo "----------------------------------"
echo "🔸 Account ID      : $ACCOUNT_ID"
echo "🔸 Project         : $PROJECT_NAME ($PROJECT_ID)"
echo "🔸 Environment     : $ENV_NAME ($ENV_ID)"
echo "🔸 Auth Type       : $AUTH_KIND"
echo "🔸 Token Type      : $TOKEN_KIND"
echo "🔸 Service Token   : $SERVICE_TOKEN"

echo "" 