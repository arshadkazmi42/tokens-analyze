#!/bin/bash

# Usage: ./packagecloud_audit.sh <API_TOKEN>

API_TOKEN="$1"
API_URL="https://packagecloud.io/api/v1/repos"

if [ -z "$API_TOKEN" ]; then
  echo "Usage: $0 <API_TOKEN>"
  exit 1
fi

RESPONSE=$(curl -s -u "$API_TOKEN:" "$API_URL")

if echo "$RESPONSE" | jq empty 2>/dev/null; then
  echo "📦 PackageCloud Repo Audit"
  echo "Generated on: $(date)"
  echo
  echo -e "REPO NAME\tOWNER\tPUBLIC\tCREATED AT\tURL" > /tmp/repos_table.txt

  echo "$RESPONSE" | jq -r '
    .[] |
    .fqname as $fq |
    ($fq | split("/") | .[0]) as $owner |
    "\(.name)\t\($owner)\t\((.private | not | tostring))\t\(.created_at)\t\(.url)"
  ' >> /tmp/repos_table.txt

  column -t -s $'\t' /tmp/repos_table.txt
  rm /tmp/repos_table.txt
else
  echo "❌ Invalid token or no repositories found."
  echo "$RESPONSE"
fi
