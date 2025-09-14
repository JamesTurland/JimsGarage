# Gain your token by heading to your NordVPN account and going to "Get Access Token"
# URL: https://my.nordaccount.com/dashboard/nordvpn/access-tokens/authorize/
$username = "token"
$password = "my-token-from-nordvpn"
$auth = "$($username):$($Password)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($auth)
$encodedCredentials = [Convert]::ToBase64String($bytes)
$url = "https://api.nordvpn.com/v1/users/services/credentials"

$headers = @{
    Authorization = "Basic $encodedCredentials"
}

# Prints out Username, Password, and Nordlynx Private Key (this is what you need for Wireguard)
Invoke-RestMethod -Uri $url -Headers $headers -Method Get

# ****IGNORE - MIGHT BE OF USE FOR SCRIPTING*******
# Send the GET request and capture the result
# $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

# Output specific properties
# $response | Select-Object id, created_at, updated_at, username, password, nordlynx_private_key

# Optionally, you can access individual properties like this:
# Write-Output "ID: $($response.id)"
# Write-Output "Username: $($response.username)"
# Write-Output "Password: $($response.password)"
# Write-Output "NordLynx Private Key: $($response.nordlynx_private_key)"