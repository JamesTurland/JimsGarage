#!/bin/bash

# Replace with your NordVPN access token
TOKEN="my-token-from-nordvpn"

# Encode credentials
ENCODED_CREDENTIALS=$(echo -n "token:$TOKEN" | base64)

# Set API URL
URL="https://api.nordvpn.com/v1/users/services/credentials"

# Make the API request and parse the result
response=$(curl -s -H "Authorization: Basic $ENCODED_CREDENTIALS" -X GET "$URL")

# Print the response (you can format it as needed)
echo "Response from NordVPN API:"
echo "$response"

# Optionally, parse specific fields (uncomment if needed)
# USERNAME=$(echo "$response" | jq -r '.username')
# PASSWORD=$(echo "$response" | jq -r '.password')
# NORDLYNX_PRIVATE_KEY=$(echo "$response" | jq -r '.nordlynx_private_key')

# echo "Username: $USERNAME"
# echo "Password: $PASSWORD"
# echo "NordLynx Private Key: $NORDLYNX_PRIVATE_KEY"
