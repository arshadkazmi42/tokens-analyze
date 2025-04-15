#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <PIVOTAL_TRACKER_API_TOKEN>"
  exit 1
fi

TOKEN="$1"
API="https://www.pivotaltracker.com/services/v5"
HEADER="X-TrackerToken: $TOKEN"

echo "🔍 Fetching user information..."
user_json=$(curl -s -H "$HEADER" -H "Content-Type: application/json" "$API/me")

name=$(echo "$user_json" | jq -r '.name // "N/A"')
email=$(echo "$user_json" | jq -r '.email // "N/A"')
username=$(echo "$user_json" | jq -r '.username // "N/A"')

echo ""
echo "👤 User Info"
echo "----------------------------------------"
echo "Name           : $name"
echo "Email          : $email"
echo "Username       : $username"

echo ""
echo "📁 Fetching accessible projects..."
projects_json=$(curl -s -H "$HEADER" -H "Content-Type: application/json" "$API/projects")

if [ "$(echo "$projects_json" | jq length)" -eq 0 ]; then
  echo "No accessible projects found or invalid token."
  exit 1
fi

echo ""
echo "📊 Project Access Report"
echo "----------------------------------------"

echo "$projects_json" | jq -c '.[]' | while read -r project; do
  project_name=$(echo "$project" | jq -r '.name')
  project_id=$(echo "$project" | jq -r '.id')
  role=$(echo "$project" | jq -r '.role // "unknown"')

  echo "🔹 Project: $project_name (ID: $project_id)"
  echo "   ➤ Role: $role"
done

echo ""
echo "✅ Analysis Complete!"
