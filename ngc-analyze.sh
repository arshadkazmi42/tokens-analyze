#!/bin/bash

# Check if api_key parameter is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <api_key>"
  exit 1
fi

API_KEY=$(echo -n '$oauthtoken:'$1 | base64)

# Step 1: Fetch the access token using the provided API key
ACCESS_TOKEN=$(curl -s -X GET "https://authn.nvidia.com/token?service=ngc" \
  -H "accept: */*" \
  -H "Authorization: Basic $API_KEY" | jq -r '.token')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to fetch access token"
  exit 1
fi

echo "Access token retrieved successfully"

# Step 2: Get user details using the access token
ME_URL="https://api.ngc.nvidia.com/v2/users/me"
user_response=$(curl -s -X GET "$ME_URL" -H "Authorization: Bearer $ACCESS_TOKEN")

if [ $? -ne 0 ]; then
  echo "Failed to fetch user details"
  exit 1
fi

# Debugging: Print the raw response to see the structure
echo "Raw user response:"
echo "$user_response"
echo "==========================================="

# Step 3: Process roles and generate report
roles_count=$(echo "$user_response" | jq '.user.roles | length')

if [ "$roles_count" -eq 0 ]; then
  echo "No roles found for the user"
  exit 1
fi

# Extract user details
user_name=$(echo "$user_response" | jq -r '.user.name')
user_email=$(echo "$user_response" | jq -r '.user.email')
user_id=$(echo "$user_response" | jq -r '.user.id')
user_status=$(echo "$user_response" | jq -r '.user.status')

echo "User Name: $user_name"
echo "User Email: $user_email"
echo "User ID: $user_id"
echo "User Status: $user_status"
echo "==========================================="

# Loop through all roles to process each organization
echo "User Roles and Organization Details:"
echo "==========================================="
for i in $(seq 0 $(($roles_count - 1))); do
  org_name=$(echo "$user_response" | jq -r ".user.roles[$i].org.name")
  org_id=$(echo "$user_response" | jq -r ".user.roles[$i].org.id")
  org_description=$(echo "$user_response" | jq -r ".user.roles[$i].org.description")

  # Debugging: Print extracted values
  echo "Extracted Org Name: $org_name"
  echo "Extracted Org ID: $org_id"
  echo "Extracted Org Description: $org_description"

  # If organization name is found, fetch the organization details
  if [ "$org_name" != "null" ]; then
    echo "Fetching details for Organization: $org_name (ID: $org_id)"
    ORG_URL="https://api.ngc.nvidia.com/v2/orgs/$org_name"

    org_response=$(curl -s -X GET "$ORG_URL" -H "Authorization: Bearer $ACCESS_TOKEN")
    if [ $? -ne 0 ]; then
      echo "Failed to fetch details for organization: $org_name"
      continue
    fi

    # Print organization details to the report
    org_role=$(echo "$user_response" | jq -r ".user.roles[$i].orgRoles | join(\", \")")
    echo "Organization Name: $org_name"
    echo "Organization ID: $org_id"
    echo "Description: $org_description"
    echo "Roles in Organization: $org_role"
    echo "-------------------------------------------"
    echo "Organization Details:"
    echo "$org_response" | jq
    echo "-------------------------------------------"
    echo ""
  else
    echo "Skipping empty or invalid organization name at index $i"
  fi
done

echo "==========================================="
echo "Bug Bounty Report Generation Complete"
echo "==========================================="
