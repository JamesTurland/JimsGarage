#!/bin/bash

# Cloudflare API details
ZONE_ID="your_zone_id"
API_TOKEN="your_cloudflare_api_token"

# Array of DNS records to update
# Format: "RECORD_ID:RECORD_NAME:PROXIED"
# PROXIED should be "true" or "false"
DNS_RECORDS=(
    "record_id_1:home.yourdomain.com:false"
    "record_id_2:server.yourdomain.com:false"
    "record_id_3:nas.yourdomain.com:true"
    # Add more records as needed
)

# Function to update a single DNS record
update_dns_record() {
    local record_id="$1"
    local record_name="$2"
    local proxied="$3"
    local current_ip="$4"
    
    echo "Processing record: $record_name (ID: $record_id)"
    
    # Get the IP stored in Cloudflare for this record
    local cloudflare_ip=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result.content')
    
    # Check if API call was successful
    if [ "$cloudflare_ip" = "null" ] || [ -z "$cloudflare_ip" ]; then
        echo "  ❌ Failed to get current IP for $record_name. Check RECORD_ID and API_TOKEN."
        return 1
    fi
    
    # Compare the IPs
    if [ "$current_ip" != "$cloudflare_ip" ]; then
        echo "  🔄 IP changed from $cloudflare_ip to $current_ip. Updating..."
        
        # Update the Cloudflare DNS record
        local update_response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$record_name"'","content":"'"$current_ip"'","ttl":120,"proxied":'"$proxied"'}')
        
        # Check if the update was successful
        if echo "$update_response" | jq -r '.success' | grep -q true; then
            echo "  ✅ DNS record updated successfully."
            return 0
        else
            echo "  ❌ Failed to update DNS record."
            echo "  Response: $update_response"
            return 1
        fi
    else
        echo "  ✓ IP unchanged ($cloudflare_ip). No update needed."
        return 0
    fi
}

# Main script execution
echo "=== Cloudflare Dynamic DNS Updater ==="
echo "Timestamp: $(date)"

# Get the current external IP
echo "Getting current external IP..."
CURRENT_IP=$(curl -s http://ipv4.icanhazip.com/)

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Failed to get current external IP. Exiting."
    exit 1
fi

echo "Current external IP: $CURRENT_IP"
echo ""

# Initialize counters
total_records=${#DNS_RECORDS[@]}
updated_count=0
failed_count=0
unchanged_count=0

# Process each DNS record
for record_entry in "${DNS_RECORDS[@]}"; do
    # Skip empty entries or comments
    if [[ -z "$record_entry" ]] || [[ "$record_entry" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    
    # Parse the record entry
    IFS=':' read -r record_id record_name proxied <<< "$record_entry"
    
    # Validate required fields
    if [ -z "$record_id" ] || [ -z "$record_name" ]; then
        echo "❌ Invalid record entry: $record_entry (missing ID or name)"
        ((failed_count++))
        continue
    fi
    
    # Set default proxied value if not specified
    if [ -z "$proxied" ]; then
        proxied="false"
    fi
    
    # Update the record
    if update_dns_record "$record_id" "$record_name" "$proxied" "$CURRENT_IP"; then
        if [ "$?" -eq 0 ]; then
            # Check if it was actually updated or unchanged
            if [[ $(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.result.content') == "$CURRENT_IP" ]]; then
                if [[ "$CURRENT_IP" != "$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
                -H "Authorization: Bearer $API_TOKEN" \
                -H "Content-Type: application/json" | jq -r '.result.content')" ]]; then
                    ((updated_count++))
                else
                    ((unchanged_count++))
                fi
            fi
        fi
    else
        ((failed_count++))
    fi
    
    echo ""
done

# Summary
echo "=== Summary ==="
echo "Total records processed: $total_records"
echo "Records updated: $updated_count"
echo "Records unchanged: $unchanged_count"
echo "Records failed: $failed_count"

if [ $failed_count -gt 0 ]; then
    exit 1
else
    exit 0
fi
