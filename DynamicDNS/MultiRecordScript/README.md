# Cloudflare Dynamic DNS Updater

A robust bash script that automatically updates multiple Cloudflare DNS records when your external IP address changes. Perfect for home labs, self-hosted services, and dynamic IP environments.

## 🚀 Key Features

### ✅ **Multiple Records Support**
- Update multiple DNS records in a single script run
- Configure different settings for each record
- Easy array-based configuration

### 🔧 **Flexible Configuration**
- Individual proxy settings per record (`true`/`false`)
- Customizable TTL values (default: 120 seconds)
- Support for different record types and names

### 🛡️ **Robust Error Handling**
- Validates API responses before proceeding
- Detailed error messages for troubleshooting
- Graceful handling of network failures
- Input validation for record configurations

### 📊 **Comprehensive Logging**
- Real-time status updates with emoji indicators
- Detailed processing logs for each record
- Summary report with statistics
- Timestamp logging for audit trails

### ⚡ **Efficient Operation**
- Single external IP lookup for all records
- Optimized API calls to minimize rate limiting
- Only updates records when IP actually changes
- Exit codes for integration with monitoring systems

## 📋 Prerequisites

- **bash** shell environment
- **curl** for API requests
- **jq** for JSON processing
- Valid Cloudflare account with API access

## ⚙️ Configuration

### 1. Cloudflare Credentials
```bash
ZONE_ID="your_actual_zone_id"
API_TOKEN="your_actual_api_token"
```




### 2. DNS Records Array

```
DNS_RECORDS=(
    "record_id_1:home.yourdomain.com:false"
    "record_id_2:server.yourdomain.com:false"
    "record_id_3:nas.yourdomain.com:true"
)
```

**Format**: `"RECORD_ID:RECORD_NAME:PROXIED"`
- **RECORD_ID**: Cloudflare DNS record identifier
- **RECORD_NAME**: Full domain name (e.g., `home.example.com`)
- **PROXIED**: `true` for Cloudflare proxy, `false` for DNS-only



## 🔍 Finding Your Cloudflare IDs

### Zone ID
1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select your domain
3. Copy the **Zone ID** from the right sidebar

### Record IDs
Use the Cloudflare API to list all DNS records:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" \
-H "Authorization: Bearer YOUR_API_TOKEN" \
-H "Content-Type: application/json"
```

### API Token
1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Create a custom token with:
   - **Zone:Zone:Read** permissions
   - **Zone:DNS:Edit** permissions
   - Include your specific zone

## 🚀 Usage

### Manual Execution
```bash
chmod +x script.sh
./script.sh
```

### Automated Execution (Cron)
Add to your crontab for automatic updates:
```bash
# Update DNS every 5 minutes
*/5 * * * * /path/to/script.sh >> /var/log/ddns.log 2>&1

# Update DNS every hour
0 * * * * /path/to/script.sh >> /var/log/ddns.log 2>&1
```

## 📊 Sample Output

```
=== Cloudflare Dynamic DNS Updater ===
Timestamp: Thu Jul 24 10:30:00 UTC 2025
Getting current external IP...
Current external IP: 203.0.113.42

Processing record: home.example.com (ID: abc123)
  🔄 IP changed from 203.0.113.41 to 203.0.113.42. Updating...
  ✅ DNS record updated successfully.

Processing record: server.example.com (ID: def456)
  ✓ IP unchanged (203.0.113.42). No update needed.

Processing record: nas.example.com (ID: ghi789)
  🔄 IP changed from 203.0.113.41 to 203.0.113.42. Updating...
  ✅ DNS record updated successfully.

=== Summary ===
Total records processed: 3
Records updated: 2
Records unchanged: 1
Records failed: 0
```

## 🔧 Advanced Configuration

### Custom TTL Values
Modify the script to use different TTL values per record:
```bash
--data '{"type":"A","name":"'"$record_name"'","content":"'"$current_ip"'","ttl":300,"proxied":'"$proxied"'}'
```

### IPv6 Support
For IPv6 records, change:
- Record type from `"A"` to `"AAAA"`
- IP service to IPv6: `curl -s http://ipv6.icanhazip.com/`

### Different IP Services
Alternative IP detection services:
- `curl -s https://ipinfo.io/ip`
- `curl -s https://api.ipify.org`
- `curl -s https://checkip.amazonaws.com`

## 🛠️ Troubleshooting

### Common Issues

**❌ Failed to get current IP**
- Check internet connectivity
- Try alternative IP detection services
- Verify firewall settings

**❌ API authentication failed**
- Verify API token permissions
- Check Zone ID accuracy
- Ensure token hasn't expired

**❌ Record not found**
- Confirm Record ID is correct
- Verify record exists in Cloudflare
- Check zone association

### Debug Mode
Add debug output by modifying curl commands:
```bash
curl -v -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id"
```

## 📝 License

This script is provided as-is for educational and personal use. Feel free to modify and distribute according to your needs.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests to improve the script.

---

**⚠️ Security Note**: Keep your API tokens secure and never commit them to version control. Consider using environment variables or secure credential storage.
