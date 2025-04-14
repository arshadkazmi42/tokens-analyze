#!/bin/bash
#
# Terraform Cloud API Token Analyzer
# ---------------------------------
# This script analyzes a Terraform Cloud personal access token (PAT)
# and generates a detailed report of access levels and permissions

# Check if token is provided
if [ -z "$1" ]; then
    echo "⚠️  Usage: $0 <TERRAFORM_CLOUD_TOKEN>"
    exit 1
fi

TF_TOKEN="$1"
TFC_URL="https://app.terraform.io/api/v2"

# Headers for API calls
HEADERS=(
    -H "Authorization: Bearer $TF_TOKEN"
    -H "Content-Type: application/vnd.api+json"
)

# Function to make API calls
call_api() {
    local endpoint="$1"
    local url="${TFC_URL}/${endpoint}"
    
    curl -s "${HEADERS[@]}" "$url"
}

# Function to handle errors
handle_error() {
    local response="$1"
    local error_msg=$(echo "$response" | jq -r '.errors[0].status + " " + .errors[0].title // "Unknown error"')
    
    echo "❌ Error: $error_msg"
    return 1
}

# Print header
echo "=================================================="
echo "🔍 Terraform Cloud Token Analysis Report"
echo "=================================================="
echo "📅 Report generated: $(date)"
echo "=================================================="

# Verify token by getting the current user account
echo "🔍 Validating token..."
ACCOUNT_INFO=$(call_api "account/details")

# Check if there was an error with the token
if echo "$ACCOUNT_INFO" | grep -q "errors"; then
    handle_error "$ACCOUNT_INFO"
    echo "❌ Invalid token or insufficient permissions"
    exit 1
fi

# Extract user info
USER_ID=$(echo "$ACCOUNT_INFO" | jq -r '.data.id')
USERNAME=$(echo "$ACCOUNT_INFO" | jq -r '.data.attributes.username')
EMAIL=$(echo "$ACCOUNT_INFO" | jq -r '.data.attributes.email')
IS_2FA=$(echo "$ACCOUNT_INFO" | jq -r '.data.attributes["two-factor"].enabled')
USER_FULLNAME=$(echo "$ACCOUNT_INFO" | jq -r '.data.attributes["full-name"]')

echo "✅ Token is valid!"
echo "👤 User: $USERNAME (${USER_FULLNAME:-Unknown})"
echo "   • Email: $EMAIL"
echo "   • User ID: $USER_ID"
echo "   • 2FA Enabled: $IS_2FA"

# Get token info
echo "🔑 Retrieving token information..."
TOKENS_INFO=$(call_api "authentication-tokens")

if echo "$TOKENS_INFO" | grep -q "errors"; then
    echo "❌ Cannot retrieve token information"
else
    # Try to find the token we're using
    TOKEN_COUNT=$(echo "$TOKENS_INFO" | jq -r '.data | length')
    echo "   • Found $TOKEN_COUNT token(s)"
    
    # Search through tokens, trying to identify the current one
    # Note: Terraform Cloud API doesn't directly tell you which token you're using
    for ((i=0; i<$TOKEN_COUNT; i++)); do
        TOKEN_ID=$(echo "$TOKENS_INFO" | jq -r ".data[$i].id")
        TOKEN_DESC=$(echo "$TOKENS_INFO" | jq -r ".data[$i].attributes.description")
        TOKEN_CREATED=$(echo "$TOKENS_INFO" | jq -r ".data[$i].attributes.created-at")
        TOKEN_LASTUSED=$(echo "$TOKENS_INFO" | jq -r ".data[$i].attributes.last-used-at")
        
        echo "   • Token: $TOKEN_DESC"
        echo "     - Created: $TOKEN_CREATED"
        echo "     - Last used: ${TOKEN_LASTUSED:-Never}"
    done
fi

# List organizations
echo "🏢 Checking organization access..."
ORGS_INFO=$(call_api "organizations")

if echo "$ORGS_INFO" | grep -q "errors"; then
    echo "❌ Cannot retrieve organizations"
else
    ORG_COUNT=$(echo "$ORGS_INFO" | jq -r '.data | length')
    
    if [ "$ORG_COUNT" -eq 0 ]; then
        echo "❌ No organizations found"
    else
        echo "✅ Found $ORG_COUNT organization(s):"
        
        for ((i=0; i<$ORG_COUNT; i++)); do
            ORG_NAME=$(echo "$ORGS_INFO" | jq -r ".data[$i].attributes.name")
            ORG_ID=$(echo "$ORGS_INFO" | jq -r ".data[$i].id")
            
            echo "   • Organization: $ORG_NAME (ID: $ORG_ID)"
            
            # Get user's permissions in this organization
            echo "     - Checking permissions..."
            ENTITLEMENTS=$(call_api "organizations/$ORG_ID/entitlement-set")
            
            # Check organization membership
            MEMBERSHIP=$(call_api "organizations/$ORG_ID/memberships?filter%5Buser%5D=$USER_ID")
            
            if echo "$MEMBERSHIP" | grep -q "errors"; then
                echo "       ❌ Could not determine membership"
            else
                # Try to get the user's role in this organization
                MEMBER_COUNT=$(echo "$MEMBERSHIP" | jq -r '.data | length')
                
                if [ "$MEMBER_COUNT" -gt 0 ]; then
                    ROLE=$(echo "$MEMBERSHIP" | jq -r '.data[0].attributes.status')
                    IS_OWNER=$(echo "$MEMBERSHIP" | jq -r '.data[0].attributes["is-organization-owner"]')
                    
                    echo "       ✅ Membership status: $ROLE"
                    if [ "$IS_OWNER" == "true" ]; then
                        echo "       ✅ Organization owner: Yes"
                    else
                        echo "       ❌ Organization owner: No"
                    fi
                else
                    echo "       ❌ Not a direct member of this organization"
                fi
            fi
            
            # Get teams in the organization that the user is a member of
            echo "     - Checking team memberships..."
            TEAMS=$(call_api "organizations/$ORG_ID/teams")
            
            if echo "$TEAMS" | grep -q "errors"; then
                echo "       ❌ Could not access teams"
            else
                TEAM_COUNT=$(echo "$TEAMS" | jq -r '.data | length')
                
                if [ "$TEAM_COUNT" -eq 0 ]; then
                    echo "       ❌ No teams found or insufficient permissions"
                else
                    echo "       ✅ Found $TEAM_COUNT team(s)"
                    USER_TEAMS=0
                    
                    for ((j=0; j<$TEAM_COUNT; j++)); do
                        TEAM_ID=$(echo "$TEAMS" | jq -r ".data[$j].id")
                        TEAM_NAME=$(echo "$TEAMS" | jq -r ".data[$j].attributes.name")
                        
                        # Check if user is in this team
                        TEAM_MEMBERS=$(call_api "teams/$TEAM_ID/memberships?filter%5Buser%5D=$USER_ID")
                        MEMBER_COUNT=$(echo "$TEAM_MEMBERS" | jq -r '.data | length')
                        
                        if [ "$MEMBER_COUNT" -gt 0 ]; then
                            echo "       • Member of team: $TEAM_NAME"
                            ((USER_TEAMS++))
                        fi
                    done
                    
                    if [ "$USER_TEAMS" -eq 0 ]; then
                        echo "       ❌ Not a member of any teams"
                    fi
                fi
            fi
            
            # List workspaces in this organization
            echo "     - Checking workspace access..."
            WS_LIST=$(call_api "organizations/$ORG_ID/workspaces?page%5Bsize%5D=20")
            
            if echo "$WS_LIST" | grep -q "errors"; then
                echo "       ❌ Could not access workspaces"
            else
                WS_COUNT=$(echo "$WS_LIST" | jq -r '.meta.pagination."total-count"')
                
                if [ "$WS_COUNT" -eq 0 ]; then
                    echo "       ❌ No workspaces found"
                else
                    echo "       ✅ Access to $WS_COUNT workspace(s)"
                    
                    # Show sample of workspaces
                    DISPLAY_COUNT=$(echo "$WS_LIST" | jq -r '.data | length')
                    
                    for ((k=0; k<$DISPLAY_COUNT && k<5; k++)); do
                        WS_NAME=$(echo "$WS_LIST" | jq -r ".data[$k].attributes.name")
                        WS_ID=$(echo "$WS_LIST" | jq -r ".data[$k].id")
                        
                        echo "         - Workspace: $WS_NAME"
                        
                        # Check workspace permissions
                        WS_PERMS=$(call_api "workspaces/$WS_ID")
                        
                        if ! echo "$WS_PERMS" | grep -q "errors"; then
                            CAN_DESTROY=$(echo "$WS_PERMS" | jq -r '.data.attributes.permissions."can-destroy-infrastructure"')
                            CAN_LOCK=$(echo "$WS_PERMS" | jq -r '.data.attributes.permissions."can-lock"')
                            CAN_QUEUE=$(echo "$WS_PERMS" | jq -r '.data.attributes.permissions."can-queue-run"')
                            CAN_UNLOCK=$(echo "$WS_PERMS" | jq -r '.data.attributes.permissions."can-unlock"')
                            
                            echo "           • Can destroy infrastructure: $CAN_DESTROY"
                            echo "           • Can lock/unlock: $CAN_LOCK/$CAN_UNLOCK"
                            echo "           • Can queue runs: $CAN_QUEUE"
                        fi
                    done
                    
                    if [ "$WS_COUNT" -gt 5 ]; then
                        echo "         ... and $(($WS_COUNT-5)) more workspaces"
                    fi
                fi
            fi
        done
    fi
fi

# Check user's API token permissions
echo "🔐 Checking token permissions..."

# Try to access sensitive endpoints to test permissions
echo "   • Testing admin access..."
ADMIN_TEST=$(call_api "admin/organizations")

if echo "$ADMIN_TEST" | grep -q "errors"; then
    echo "   ❌ No admin access"
else
    echo "   ⚠️ WARNING: Token has admin privileges!"
fi

# Try to get runs as a test for read permissions
echo "   • Testing runs access..."
RUNS_TEST=$(call_api "runs")

if echo "$RUNS_TEST" | grep -q "errors"; then
    echo "   ❌ Limited or no access to runs"
else
    echo "   ✅ Can access runs"
fi

# Try to get registry modules as a test for registry permissions
echo "   • Testing registry access..."
REG_TEST=$(call_api "registry-modules")

if echo "$REG_TEST" | grep -q "errors"; then
    echo "   ❌ Limited or no access to registry"
else
    echo "   ✅ Can access registry modules"
fi

echo "=================================================="
echo "🧪 Testing specific permissions..."

# Testing various permissions endpoints
PERMISSIONS=(
    "plans:read"
    "plans:write"
    "state-versions:create"
    "state-versions:read"
    "variables:read"
    "variables:write"
    "runs:read"
    "runs:apply"
    "workspaces:create"
    "workspaces:read"
    "workspaces:write"
    "workspaces:delete"
)

echo "   The following permissions are estimates based on API responses:"
for PERM in "${PERMISSIONS[@]}"; do
    # We have already tested some permissions above
    case $PERM in
        "runs:read")
            if ! echo "$RUNS_TEST" | grep -q "errors"; then
                echo "   ✅ $PERM"
            else
                echo "   ❌ $PERM"
            fi
            ;;
        *)
            # For other permissions, we make an educated guess based on organization and workspace access
            if [ "$ORG_COUNT" -gt 0 ]; then
                if [[ "$PERM" == *":read"* ]]; then
                    echo "   ✅ Likely has $PERM"
                elif [[ "$IS_OWNER" == "true" ]]; then
                    echo "   ✅ Likely has $PERM (as organization owner)"
                else
                    echo "   ⚠️ May have $PERM (depends on team permissions)"
                fi
            else
                echo "   ❓ Unknown: $PERM"
            fi
            ;;
    esac
done

echo "=================================================="
echo "✅ Analysis complete!"
echo "=================================================="
