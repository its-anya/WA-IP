$processedIPs = @{}

function Get-EnhancedIPInfo {
    param([string]$IPAddress)
    if ($processedIPs.ContainsKey($IPAddress)) { return $processedIPs[$IPAddress] }

    $apis = @(
        @{ Url = "http://ipapi.co/$IPAddress/json/"; Name = "ipapi.co" },
        @{ Url = "http://ip-api.com/json/$IPAddress"; Name = "ip-api.com" }
    )

    foreach ($api in $apis) {
        try {
            $response = Invoke-RestMethod -Uri $api.Url -Method Get -TimeoutSec 3
            if ($api.Name -eq "ipapi.co" -and $response.ip) {
                $info = @{
                    "Source" = $api.Name; "IP" = $IPAddress;
                    "City" = $response.city; "Region" = $response.region;
                    "Country" = $response.country_name; "ISP" = $response.org;
                    "Timezone" = $response.timezone;
                    "Coordinates" = if ($response.latitude) { "$($response.latitude),$($response.longitude)" } else { "N/A" }
                }
                $processedIPs[$IPAddress] = $info; return $info
            } elseif ($api.Name -eq "ip-api.com" -and $response.status -eq "success") {
                $info = @{
                    "Source" = $api.Name; "IP" = $IPAddress;
                    "City" = $response.city; "Region" = $response.regionName;
                    "Country" = $response.country; "ISP" = $response.isp;
                    "Timezone" = $response.timezone;
                    "Coordinates" = "$($response.lat),$($response.lon)"
                }
                $processedIPs[$IPAddress] = $info; return $info
            }
        } catch { continue }
    }
    return $null
}

function Show-EnhancedLocationInfo {
    param($locationInfo)
    if ($locationInfo) {
        Write-Host "`n📍 TARGET LOCATION FOUND:" -ForegroundColor Magenta
        Write-Host "IP: $($locationInfo.IP) — $($locationInfo.City), $($locationInfo.Region), $($locationInfo.Country)"
        Write-Host "ISP: $($locationInfo.ISP) | TZ: $($locationInfo.Timezone) | Coords: $($locationInfo.Coordinates)"
        if ($locationInfo.Coordinates -ne "N/A") {
            Write-Host "Google Maps: https://www.google.com/maps?q=$($locationInfo.Coordinates)" -ForegroundColor Yellow
        }
    }
}
