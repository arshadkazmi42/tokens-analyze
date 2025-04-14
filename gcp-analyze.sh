#!/bin/bash

# Usage: ./gcp_access_report.sh /path/to/gcp.json

if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/gcp.json"
  exit 1
fi

KEY_FILE="$1"

echo "🔑 Activating service account..."
gcloud auth activate-service-account --key-file="$KEY_FILE" >/dev/null 2>&1

echo "🔍 Fetching project info..."
PROJECT_ID=$(jq -r '.project_id' "$KEY_FILE")
ACCOUNT_EMAIL=$(jq -r '.client_email' "$KEY_FILE")
ACCOUNT_ID=$(jq -r '.client_id' "$KEY_FILE")

# Fetch organization ID
ORG_ID=$(gcloud projects get-ancestors "$PROJECT_ID" --format="value(id)" | head -1)

# Get IAM roles for the service account
echo "🔐 Fetching IAM roles for the service account..."
IAM_ROLES=$(gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --format='table(bindings.role)' \
  --filter="bindings.members:$ACCOUNT_EMAIL")

# Get billing info
echo "💰 Checking billing info..."
BILLING_ACCOUNT=$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingAccountName)")

# Output report
echo ""
echo "========= GCP ACCESS REPORT ========="
echo "📧 Service Account: $ACCOUNT_EMAIL"
echo "🆔 Client ID: $ACCOUNT_ID"
echo "🏢 Project ID: $PROJECT_ID"
echo "🏦 Billing Account: ${BILLING_ACCOUNT:-Not Linked}"
echo "🏛️ Organization ID: ${ORG_ID:-Unknown}"
echo ""
echo "Roles assigned to this account:"
echo "$IAM_ROLES"
echo "====================================="

# Optional: deactivate account
gcloud auth revoke "$ACCOUNT_EMAIL" --quiet
