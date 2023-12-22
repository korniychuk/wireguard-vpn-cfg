#!/usr/bin/env bash

declare -r DEFAULT_SERVER_PORT=51820
declare -r DEFAULT_INTERNAL_SUBNET="10.13.13.0"

function generate_dotenv() {
  # Ask for VPN URL
  while true; do
      read -r -p "Enter the VPN URL (domain) [e.g., vpn.example.com]: " SERVER_URL
      # Remove protocols if present and validate URL is not empty
      SERVER_URL=$(echo "$SERVER_URL" | sed -e 's|^[^:]*://||')
      if [[ -z "$SERVER_URL" ]]; then
          echo "VPN URL cannot be empty. Please enter a valid URL."
      else
          break
      fi
  done

  read -r -p "Enter the Server Port or press Enter for default [$DEFAULT_SERVER_PORT]: " SERVER_PORT
  SERVER_PORT=${SERVER_PORT:-$DEFAULT_SERVER_PORT}

  read -r -p "Enter the Internal Subnet or press Enter for default [$DEFAULT_INTERNAL_SUBNET]: " INTERNAL_SUBNET
  INTERNAL_SUBNET=${INTERNAL_SUBNET:-$DEFAULT_INTERNAL_SUBNET}

  echo "Writing to .env file..."
  {
    echo '# WireGuard server settings'
    echo "SERVER_URL=$SERVER_URL"
    echo "SERVER_PORT=$SERVER_PORT"
    echo "INTERNAL_SUBNET=$INTERNAL_SUBNET"
    echo "ALLOWEDIPS=0.0.0.0/0"
  } > .env

  echo
  cat .env
  echo

  echo ".env file created successfully."
}

generate_dotenv
