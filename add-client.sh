#!/usr/bin/env bash

declare -r WG_CONF='./config/wg_confs/wg0.conf'

function die() {
    local msg=$1
    local -i code=${2:-1}

    echo "❌ Error: $msg" >&2
    exit $code
}

[[ ! -f "$WG_CONF" ]] || die "Can't find $WG_CONF"

# Read environment variables
source .env
[[ -z "$SERVER_URL" ]]       && die "No SERVER_URL"
[[ -z "$SERVER_PORT" ]]      && die "No SERVER_PORT"
[[ -z "$ALLOWEDIPS" ]]       && die "No ALLOWEDIPS"
[[ -z "$INTERNAL_SUBNET" ]]  && die "No INTERNAL_SUBNET"


[[ "$INTERNAL_SUBNET" =~ \.0$ ]] || die "INTERNAL_SUBNET should end .0"
declare -r INTERNAL_SUBNET_PREFIX="${INTERNAL_SUBNET%0*}"

read -r -p "INTERNAL_SUBNET_PREFIX: $INTERNAL_SUBNET_PREFIX. Does this look good? Y/n: " response
response=${response,,} # Convert response to lowercase
# shellcheck disable=2181
[[ $? -ne 0 ]] && die "Unexpected error. Mostly unsupported bash version."


[[ "$response" =~ ^(yes|y| ) ]] || [[ -z "$response" ]] || die "Invalid INTERNAL_SUBNET_PREFIX. Mostly it's a bug."


# Extract the last part of AllowedIPs to get the latest peer ID
INTERNAL_SUBNET_PREFIX_REG="$(echo -n "$INTERNAL_SUBNET_PREFIX" | sed 's@\.@\\.@g')"
LAST_IP_PART=$(grep -oP '^\s*AllowedIPs\s*=\s*'"$INTERNAL_SUBNET_PREFIX_REG"'\K\d+' "$WG_CONF" | sort -n | tail -1)
if ! [[ "$LAST_IP_PART" =~ ^[0-9]+$ ]]; then
    echo "Warn! Can't extract a valid IP part for PEER_ID." >&2

    read -r -p "Do you want to use LAST_IP_PART=2 (first user)? Y/n: " response
    response=${response,,} # Convert response to lowercase
    [[ "$response" =~ ^(yes|y| ) ]] || [[ -z "$response" ]] || die "Could not extract a valid IP part for PEER_ID"
    LAST_IP_PART=2
fi

# Calculate the next PEER_ID by adding 1 to the last part of the IP
LAST_PEER_ID=$((LAST_IP_PART - 1))
if ! [[ "$LAST_PEER_ID" =~ ^[0-9]+$ ]]; then
    echo "Error: LAST_PEER_ID is not a valid number."
    exit 1
fi
if [[ "$LAST_PEER_ID" -lt 1 ]]; then 
    echo "Error: LAST_PEER_ID is out of range. It should be bigger than 1."
    exit 1
fi

# Increment LAST_PEER_ID by 1 since we're adding a new client
PEER_ID=$((LAST_PEER_ID + 1))
if [[ "$PEER_ID" -lt 1 || "$PEER_ID" -gt 254 ]]; then  # Check if it's within an acceptable range (you can modify the range)
    echo "Error: PEER_ID is out of range. It should be between 1 and 254."
    exit 1
fi

# Generate Client IP
CLIENT_IP="$INTERNAL_SUBNET_PREFIX.$((PEER_ID + 1))"

# Ask for Client Comment
read -r -p "Enter a comment for this client (Ex.: \"MacBook Pro 16'' 2023\", \"Darina's iPad 12''\"): " CLIENT_COMMENT
if [ -z "$CLIENT_COMMENT" ]; then
    echo "Error: Comment can't be empty."
    exit 1
fi

# Prepare client and server configuration directories
mkdir -p ./config/peer${PEER_ID}

# Generate keys for the new peer
docker-compose exec -T wireguard wg genkey > ./config/peer${PEER_ID}/privatekey-peer${PEER_ID}
docker-compose exec -T wireguard wg pubkey < ./config/peer${PEER_ID}/privatekey-peer${PEER_ID} > ./config/peer${PEER_ID}/publickey-peer${PEER_ID}
docker-compose exec -T wireguard wg genpsk > ./config/peer${PEER_ID}/presharedkey-peer${PEER_ID}

# Verify key generation
if [[ ! -s ./config/peer${PEER_ID}/privatekey-peer${PEER_ID} || ! -s ./config/peer${PEER_ID}/publickey-peer${PEER_ID} || ! -s ./config/peer${PEER_ID}/presharedkey-peer${PEER_ID} ]]; then
    echo "Error: Key files are empty. Exiting."
    exit 1
fi

# Generate client config
cat <<EOL > ./config/peer${PEER_ID}/peer${PEER_ID}.conf
[Interface]
Address = ${CLIENT_IP}/32
PrivateKey = $(cat ./config/peer${PEER_ID}/privatekey-peer${PEER_ID})
ListenPort = 51820
DNS = ${PEERDNS}

[Peer]
PublicKey = $(cat ./config/server/publickey-server)
PresharedKey = $(cat ./config/peer${PEER_ID}/presharedkey-peer${PEER_ID})
Endpoint = ${SERVER_URL}:${SERVER_PORT}
AllowedIPs = ${ALLOWEDIPS}
EOL

# Generate server peer config
cat <<EOL >> "$WG_CONF"
[Peer]
# (${PEER_ID}) ${CLIENT_COMMENT}
PublicKey = $(cat ./config/peer${PEER_ID}/publickey-peer${PEER_ID})
PresharedKey = $(cat ./config/peer${PEER_ID}/presharedkey-peer${PEER_ID})
AllowedIPs = ${CLIENT_IP}/32

EOL

# Restart the WireGuard container
docker-compose restart wireguard

# Print useful details
LOCAL_CFG_NAME=$(echo "$CLIENT_COMMENT" | sed 's/[^a-zA-Z0-9 ]/-/g'  | awk 'BEGIN{FS=OFS="-"} {gsub(/^-+|-+$/, "", $0)} 1')
echo
echo -e "\033[1;32m=== 💬 \033[1;34m$CLIENT_COMMENT: 🆔 \033[1;34m$PEER_ID\033[1;32m | 🌐 \033[1;34m$CLIENT_IP\033[1;32m\033[1;32m ===\033[0m"
echo
echo -e "\033[1;33mTo copy the client config to your local machine, run:\033[0m"
echo "scp ${USER}@${SERVER_URL}:$(pwd)/config/peer${PEER_ID}/peer${PEER_ID}.conf './$LOCAL_CFG_NAME.conf'"
echo

# Generate QR code after restarting WireGuard
docker-compose exec -T wireguard qrencode -t ansiutf8 < ./config/peer${PEER_ID}/peer${PEER_ID}.conf

