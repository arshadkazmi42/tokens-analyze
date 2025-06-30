#!/usr/bin/env bash

# --- Validate Args ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <sandbox|production> <public_key> <private_key> [merchant_id]"
  exit 1
fi

BT_ENV="$1"
PUBLIC_KEY="$2"
PRIVATE_KEY="$3"
MERCHANT_ID="$4"  # Optional

if [[ "$BT_ENV" == "sandbox" ]]; then
  URL="https://payments.sandbox.braintree-api.com/graphql"
elif [[ "$BT_ENV" == "production" ]]; then
  URL="https://payments.braintree-api.com/graphql"
else
  echo "❌ Invalid environment: must be 'sandbox' or 'production'"
  exit 1
fi

# --- Request Helper ---
function gql() {
  local query="$1"
  curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "Braintree-Version: 2019-01-01" \
    -u "$PUBLIC_KEY:$PRIVATE_KEY" \
    -d "$query"
}

# --- Ping Check ---
echo -e "\n🔄 Verifying credentials..."
PING=$(gql '{"query":"query { ping }"}' | jq -r '.data.ping // "fail"')
[[ "$PING" != "pong" ]] && { echo "❌ Ping failed — invalid or limited credentials"; exit 1; }
echo "✅ Ping successful"

# --- Merchant Info ---
if [ -n "$MERCHANT_ID" ]; then
  echo -e "\n🏢 Fetching specific merchant account: $MERCHANT_ID"
  QUERY=$(jq -cn --arg id "$MERCHANT_ID" '{"query":"query getAccount($id: ID!) { merchantAccount(id: $id) { id name status currencyIsoCode } }","variables":{"id":$id}}')
  gql "$QUERY" | jq -r '
    .data.merchantAccount // {} |
    ["ID", "Name", "Status", "Currency"],
    [.id, .name, .status, .currencyIsoCode] |
    @tsv' | column -t
else
  echo -e "\n🏢 Fetching first 10 merchant accounts:"
  gql '{"query":"query { merchantAccounts(first: 10) { edges { node { id name status currencyIsoCode }}}}"}' |
    jq -r '
      .data.merchantAccounts.edges[]?.node |
      ["ID", "Name", "Status", "Currency"],
      [.id, .name, .status, .currencyIsoCode] |
      @tsv' | column -t
fi

# --- Capabilities / Env Info ---
echo -e "\n⚙️ Configuration:"
gql '{"query":"query { configuration { supportedCurrencies environment merchantId } }"}' |
  jq -r '
    .configuration as $c |
    if $c then
      ["Environment", "Merchant ID", "Currencies"],
      [$c.environment, $c.merchantId, ($c.supportedCurrencies | join(","))]
    else
      ["Environment", "Merchant ID", "Currencies"],
      ["N/A", "N/A", "N/A"]
    end | @tsv' | column -t
