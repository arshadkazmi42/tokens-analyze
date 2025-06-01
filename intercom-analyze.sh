#!/bin/bash

# Usage: ./intercom_token_analyzer.sh YOUR_TOKEN

TOKEN="$1"

if [ -z "$TOKEN" ]; then
  echo "❌ Please provide Intercom token as first argument."
  exit 1
fi

HEADERS=(
  -H "Authorization: Bearer $TOKEN"
  -H "Accept: application/json"
  -H "Content-Type: application/json"
)

# Get /me info
ME_RESPONSE=$(curl -s "${HEADERS[@]}" https://api.intercom.io/me)
if echo "$ME_RESPONSE" | grep -q '"type":"error"'; then
  echo "❌ Invalid token or error in /me endpoint:"
  echo "$ME_RESPONSE" | jq
  exit 1
fi

APP_ID=$(echo "$ME_RESPONSE" | jq -r '.app.id // "-"')
APP_NAME=$(echo "$ME_RESPONSE" | jq -r '.app.name // "-"')
EMAIL=$(echo "$ME_RESPONSE" | jq -r '.email // "-"')
USER_ID=$(echo "$ME_RESPONSE" | jq -r '.id // "-"')
TYPE=$(echo "$ME_RESPONSE" | jq -r '.type // "-"')

# Get scopes from /auth
AUTH_RESPONSE=$(curl -s "${HEADERS[@]}" https://api.intercom.io/auth)
SCOPES=$(echo "$AUTH_RESPONSE" | jq -r '.oauth.scopes | join(", ")' 2>/dev/null)
SCOPES=${SCOPES:-"N/A"}

echo ""
echo "==================== Intercom Access Token Info ===================="
printf "%-20s %s\n" "App ID:" "$APP_ID"
printf "%-20s %s\n" "Workspace Name:" "$APP_NAME"
printf "%-20s %s\n" "Email:" "$EMAIL"
printf "%-20s %s\n" "User ID:" "$USER_ID"
printf "%-20s %s\n" "Type:" "$TYPE"
printf "%-20s %s\n" "Scopes:" "$SCOPES"
echo "===================================================================="
echo ""

# Function to fetch and print contacts with companies
fetch_contacts() {
  PAGE_URL="https://api.intercom.io/contacts?per_page=50"
  echo "🏢 Companies and 👤 Contacts (Name, Email, Phone):"
  echo "===================================================================="
  # Print header for table
  printf "%-25s %-30s %-30s %-15s\n" "Company Name" "Contact Name" "Contact Email" "Contact Phone"
  echo "--------------------------------------------------------------------"

  while [ -n "$PAGE_URL" ]; do
    RESPONSE=$(curl -s "${HEADERS[@]}" "$PAGE_URL")

    # Extract contacts array
    CONTACTS=$(echo "$RESPONSE" | jq -c '.contacts[]?')

    # Loop through each contact
    echo "$CONTACTS" | while IFS= read -r contact; do
      # Contact fields
      CONTACT_NAME=$(echo "$contact" | jq -r '.name // "-"')
      CONTACT_EMAIL=$(echo "$contact" | jq -r '.email // "-"')
      CONTACT_PHONE=$(echo "$contact" | jq -r '.phone // "-"')

      # Companies array for this contact
      COMPANIES=$(echo "$contact" | jq -c '.companies.companies // []')

      # If no companies, print contact alone with "-"
      if [ "$(echo "$COMPANIES" | jq length)" -eq 0 ]; then
        printf "%-25s %-30s %-30s %-15s\n" "-" "$CONTACT_NAME" "$CONTACT_EMAIL" "$CONTACT_PHONE"
      else
        # Print one row per company
        echo "$COMPANIES" | jq -c '.[]' | while IFS= read -r company; do
          COMPANY_NAME=$(echo "$company" | jq -r '.name // "-"')
          printf "%-25s %-30s %-30s %-15s\n" "$COMPANY_NAME" "$CONTACT_NAME" "$CONTACT_EMAIL" "$CONTACT_PHONE"
        done
      fi
    done

    # Pagination: next page URL or empty
    PAGE_URL=$(echo "$RESPONSE" | jq -r '.pages.next // empty')
  done
  echo "===================================================================="
}

fetch_contacts
