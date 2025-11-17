#!/bin/bash

# Usage: ./webex_analyze.sh <WEBEX_TOKEN>
TOKEN="$1"

if [ -z "$TOKEN" ]; then
    echo "Usage: $0 <WEBEX_TOKEN>"
    exit 1
fi

HEADER="Authorization: Bearer $TOKEN"

echo "=== Running Webex API Analysis ==="
echo

########################################
# GET people/me
########################################
CURL_ME="curl -s -H \"$HEADER\" https://webexapis.com/v1/people/me"
echo "[+] Request: $CURL_ME"
USER_JSON=$(eval $CURL_ME)

USER_ID=$(echo "$USER_JSON" | jq -r '.id')
USER_NAME=$(echo "$USER_JSON" | jq -r '.displayName')
USER_EMAIL=$(echo "$USER_JSON" | jq -r '.emails[0]')
USER_TYPE=$(echo "$USER_JSON" | jq -r '.type')
ORG_ID=$(echo "$USER_JSON" | jq -r '.orgId')

echo
echo "=== User Info ==="
printf "ID: %s\nName: %s\nEmail: %s\nType: %s\nOrgID: %s\n" \
"$USER_ID" "$USER_NAME" "$USER_EMAIL" "$USER_TYPE" "$ORG_ID"
echo

########################################
# GET organization
########################################
CURL_ORG="curl -s -H \"$HEADER\" https://webexapis.com/v1/organizations/$ORG_ID"
echo "[+] Request: $CURL_ORG"
ORG_JSON=$(eval $CURL_ORG)

ORG_NAME=$(echo "$ORG_JSON" | jq -r '.displayName // "N/A"')
ORG_TYPE=$(echo "$ORG_JSON" | jq -r '.type // "N/A"')

echo
echo "=== Organization Info ==="
printf "OrgID: %s\nName: %s\nType: %s\n" \
"$ORG_ID" "$ORG_NAME" "$ORG_TYPE"
echo

########################################
# GET rooms
########################################
CURL_ROOMS="curl -s -H \"$HEADER\" https://webexapis.com/v1/rooms"
echo "[+] Request: $CURL_ROOMS"
ROOMS_JSON=$(eval $CURL_ROOMS)

echo
echo "=== Rooms (Accessible by token) ==="
printf "ID\tTitle\tType\tPublic\n"

echo "$ROOMS_JSON" | jq -r '.items[] | [.id, .title, .type, .isPublic] | @tsv' |
while IFS=$'\t' read -r rid rtitle rtype rpub; do
    printf "%s\t%s\t%s\t%s\n" "$rid" "$rtitle" "$rtype" "$rpub"
done
echo

########################################
# GET memberships
########################################
CURL_MEMBERSHIPS="curl -s -H \"$HEADER\" https://webexapis.com/v1/memberships"
echo "[+] Request: $CURL_MEMBERSHIPS"
MEMBERS_JSON=$(eval $CURL_MEMBERSHIPS)

echo
echo "=== Memberships (Which rooms user is in) ==="
printf "RoomID\tPersonID\tIsModerator\n"

echo "$MEMBERS_JSON" | jq -r '.items[] | [.roomId, .personId, .isModerator] | @tsv' |
while IFS=$'\t' read -r roomId personId moderator; do
    printf "%s\t%s\t%s\n" "$roomId" "$personId" "$moderator"
done
echo

########################################
# PRINT SUMMARY
########################################
echo "=== Summary ==="
echo "User: $USER_NAME <$USER_EMAIL>"
echo "Org:  $ORG_NAME"
echo "Rooms accessible: $(echo "$ROOMS_JSON" | jq '.items | length')"
echo "Memberships: $(echo "$MEMBERS_JSON" | jq '.items | length')"

echo
echo "=== Done ==="
