#!/bin/bash

# Cloudflare API details
ZONE_ID="your_zone_id"
RECORD_ID="your_record_id"
API_TOKEN="your_cloudflare_api_token"
RECORD_NAME="your_domain.com"

# Get the current external IP
CURRENT_IP=$(curl -s http://ipv4.icanhazip.com/)

# Get the IP stored in Cloudflare
CLOUDFLARE_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
-H "Authorization: Bearer $API_TOKEN" \
-H "Content-Type: application/json" | jq -r '.result.content')

# Compare the IPs
if [ "$CURRENT_IP" != "$CLOUDFLARE_IP" ]; then
  echo "IP has changed from $CLOUDFLARE_IP to $CURRENT_IP. Updating DNS record..."

  # Update the Cloudflare DNS record
  UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$CURRENT_IP"'","ttl":120,"proxied":false}')

  # Check if the update was successful
  if echo "$UPDATE_RESPONSE" | jq -r '.success' | grep -q true; then
    echo "DNS record updated successfully."
  else
    echo "Failed to update DNS record. Response from Cloudflare: $UPDATE_RESPONSE"
  fi
else
  echo "IP has not changed. No update needed."
fi
