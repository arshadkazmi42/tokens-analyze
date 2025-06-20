#!/usr/bin/env bash

TOKEN="$1"
API="https://sentry.io/api/0"
ORG_SLUG_GUESS=""
TMP_OUT="/tmp/sentry_token_analyze.$$"

if [ -z "$TOKEN" ]; then
  echo "Usage: $0 <SENTRY_AUTH_TOKEN>"
  exit 1
fi

print_section() {
  echo
  echo "========== $1 =========="
}

print_table() {
  column -t -s $'\t'
}

check_access() {
  local name="$1"
  local url="$2"
  local jq_filter="$3"

  local response
  response=$(curl -s -H "Authorization: Bearer $TOKEN" "$url")
  local status=$?

  if [[ "$response" == *"permission"* || "$response" == *"Permission Denied"* ]]; then
    echo -e "$name\t❌ No Access"
  elif [[ $status -ne 0 || -z "$response" ]]; then
    echo -e "$name\t❌ Error or Empty"
  else
    echo -e "$name\t✅ OK"
    if [ -n "$jq_filter" ]; then
      echo "$response" | jq -r "$jq_filter" > "$TMP_OUT.$name"
    fi
  fi
}

print_section "Checking API Access"

echo -e "Endpoint\tStatus"
check_access "Projects" "$API/projects/" '.[] | [.organization.slug, .slug, .name, .id] | @tsv'
check_access "Organizations" "$API/organizations/" '.[] | [.slug, .name, .id] | @tsv'
check_access "User Info" "$API/users/me/" '[.id, .email, .name] | @tsv'
# Guess org slug from project fallback
ORG_SLUG_GUESS=$(cat "$TMP_OUT.Projects" 2>/dev/null | head -n1 | cut -f1)
if [ -n "$ORG_SLUG_GUESS" ]; then
  check_access "Teams" "$API/organizations/$ORG_SLUG_GUESS/teams/" '.[] | [.slug, .name] | @tsv'
fi

echo ""

# Print available content from parsed files
[[ -f "$TMP_OUT.User Info" ]] && {
  print_section "👤 User Info"
  echo -e "ID\tEmail\tName"
  cat "$TMP_OUT.User Info" | print_table
}

[[ -f "$TMP_OUT.Organizations" ]] && {
  print_section "🏢 Organizations"
  echo -e "Slug\tName\tID"
  cat "$TMP_OUT.Organizations" | print_table
}

[[ -f "$TMP_OUT.Projects" ]] && {
  print_section "📦 Projects"
  echo -e "Org Slug\tProject Slug\tProject Name\tProject ID"
  cat "$TMP_OUT.Projects" | print_table
}

[[ -f "$TMP_OUT.Teams" ]] && {
  print_section "👥 Teams (from org: $ORG_SLUG_GUESS)"
  echo -e "Team Slug\tTeam Name"
  cat "$TMP_OUT.Teams" | print_table
}

# Cleanup
rm -f "$TMP_OUT"*
