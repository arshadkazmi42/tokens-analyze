#!/bin/bash

# Usage: ./dockerhub-analyzer.sh <username> <password_or_token>

USERNAME="$1"
PASSWORD="$2"

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
  echo "Usage: $0 <dockerhub_username> <password_or_token>"
  exit 1
fi

# Check dependencies
if ! command -v jq &>/dev/null || ! command -v column &>/dev/null; then
  echo "[!] This script requires 'jq' and 'column'. Install them first."
  exit 1
fi

echo "[*] Authenticating..."

TOKEN=$(curl -s -X POST https://hub.docker.com/v2/users/login/ \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}" | jq -r .token)

if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
  echo "[!] Authentication failed. Check credentials."
  exit 1
fi

echo "[+] Authenticated successfully."

# User Info
echo
echo "============================"
echo "🧑 USER DETAILS"
echo "============================"
USER_INFO=$(curl -s -H "Authorization: JWT $TOKEN" https://hub.docker.com/v2/users/$USERNAME/)
echo "$USER_INFO" | jq -r '"Username: \(.username)\nFull Name: \(.full_name)\nCompany: \(.company)\nLocation: \(.location)\nIs Staff: \(.is_staff)"'
echo

# Orgs
echo "============================"
echo "🏢 ORGANIZATIONS"
echo "============================"
ORGS=$(curl -s -H "Authorization: JWT $TOKEN" https://hub.docker.com/v2/orgs/ | jq -r '.results[].name')

if [[ -z "$ORGS" ]]; then
  echo "No organizations found."
else
  for ORG in $ORGS; do
    echo
    echo "▶️ Org: $ORG"
    echo "Repository Name | Private | Pull Count | Description"
    echo "--------------- | ------- | ---------- | -----------"
    PAGE=1
    while :; do
      REPO_RESPONSE=$(curl -s -H "Authorization: JWT $TOKEN" "https://hub.docker.com/v2/repositories/$ORG/?page=$PAGE")
      REPOS=$(echo "$REPO_RESPONSE" | jq -e '.results // empty | .[] | "\(.name) | \(.is_private) | \(.pull_count) | \(.description // "-")"' 2>/dev/null)
      [[ -z "$REPOS" ]] && break
      echo "$REPOS"
      ((PAGE++))
    done | column -t -s '|'
  done
fi

# User Repos
echo
echo "============================"
echo "📦 PERSONAL REPOSITORIES"
echo "============================"
echo "Repository Name | Private | Pull Count | Description"
echo "--------------- | ------- | ---------- | -----------"
PAGE=1
while :; do
  REPOS=$(curl -s -H "Authorization: JWT $TOKEN" "https://hub.docker.com/v2/repositories/$USERNAME/?page=$PAGE" | jq -r '.results[] | "\(.name) | \(.is_private) | \(.pull_count) | \(.description // "-")"')
  [[ -z "$REPOS" ]] && break
  echo "$REPOS"
  ((PAGE++))
done | column -t -s '|'

echo
echo "[✓] Report complete."
