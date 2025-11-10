# Advanced WhatsApp IP Detector with Enhanced Geolocation
# Run as Administrator

param(
    [int]$AnalysisWindow = 30  # Seconds to analyze IP patterns
)

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Run as Administrator!" -ForegroundColor Red
    exit
}

$tshark = "C:\Program Files\Wireshark\tshark.exe"
if (-not (Test-Path $tshark)) {
    Write-Host "Install Wireshark!" -ForegroundColor Red
    exit
}

# Enhanced IP analysis
$ipTracker = @{}
$processedIPs = @{}
$startTime = Get-Date

function Get-EnhancedIPInfo {
    param([string]$IPAddress)
    
    if ($processedIPs.ContainsKey($IPAddress)) {
        return $processedIPs[$IPAddress]
    }
    
    Write-Host "   🔍 Looking up geolocation..." -ForegroundColor DarkYellow
    
    try {
        # Try multiple free APIs for better accuracy
        $apis = @(
            @{ Url = "http://ipapi.co/$IPAddress/json/"; Name = "ipapi.co" },
            @{ Url = "http://ip-api.com/json/$IPAddress"; Name = "ip-api.com" }
        )
        
        foreach ($api in $apis) {
            try {
                $response = Invoke-RestMethod -Uri $api.Url -Method Get -TimeoutSec 3
                
                if ($api.Name -eq "ipapi.co" -and $response.ip) {
                    $info = @{
                        "Source" = $api.Name
                        "IP" = $IPAddress
                        "City" = $response.city
                        "Region" = $response.region
                        "Country" = $response.country_name
                        "ISP" = $response.org
                        "Timezone" = $response.timezone
                        "Coordinates" = if ($response.latitude) { "$($response.latitude),$($response.longitude)" } else { "N/A" }
                    }
                    $processedIPs[$IPAddress] = $info
                    return $info
                }
                elseif ($api.Name -eq "ip-api.com" -and $response.status -eq "success") {
                    $info = @{
                        "Source" = $api.Name
                        "IP" = $IPAddress
                        "City" = $response.city
                        "Region" = $response.regionName
                        "Country" = $response.country
                        "ISP" = $response.isp
                        "Timezone" = $response.timezone
                        "Coordinates" = "$($response.lat),$($response.lon)"
                    }
                    $processedIPs[$IPAddress] = $info
                    return $info
                }
            } catch {
                continue
            }
        }
    } catch {
        Write-Debug "All geolocation APIs failed"
    }
    
    return $null
}

function Show-EnhancedLocationInfo {
    param($locationInfo)
    
    if ($locationInfo) {
        Write-Host "`n📍 TARGET LOCATION FOUND:" -ForegroundColor Magenta -BackgroundColor Black
        Write-Host "   ┌──────────────────────────────────────────────────────" -ForegroundColor Magenta
        Write-Host "   │ IP Address: $($locationInfo.IP)" -ForegroundColor White
        Write-Host "   │ Location: $($locationInfo.City), $($locationInfo.Region)" -ForegroundColor White
        Write-Host "   │ Country: $($locationInfo.Country)" -ForegroundColor White
        Write-Host "   │ ISP: $($locationInfo.ISP)" -ForegroundColor White
        Write-Host "   │ Timezone: $($locationInfo.Timezone)" -ForegroundColor White
        Write-Host "   │ Coordinates: $($locationInfo.Coordinates)" -ForegroundColor White
        
        if ($locationInfo.Coordinates -ne "N/A") {
            $mapsUrl = "https://www.google.com/maps?q=$($locationInfo.Coordinates)"
            Write-Host "   │ Google Maps: $mapsUrl" -ForegroundColor Yellow
        }
        
        Write-Host "   └──────────────────────────────────────────────────────" -ForegroundColor Magenta
        Write-Host "   Data Source: $($locationInfo.Source)" -ForegroundColor DarkGray
    }
}

# Main execution
Write-Host "=== ADVANCED WHATSAPP IP DETECTOR ===" -ForegroundColor Green
Write-Host "Starting at: $(Get-Date)" -ForegroundColor Cyan

$localIP = (Get-NetIPAddress -InterfaceAlias "WiFi" -AddressFamily IPv4).IPAddress
Write-Host "Monitoring IP: $localIP" -ForegroundColor Green

Write-Host "`n🎯 INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "   1. Start WhatsApp Desktop" -ForegroundColor White
Write-Host "   2. Call target NOW (they must answer)" -ForegroundColor White
Write-Host "   3. Target IP + location will auto-appear" -ForegroundColor White
Write-Host "   4. Press Ctrl+C to stop" -ForegroundColor White
Write-Host "`n" + "="*60 -ForegroundColor Cyan

Write-Host "[+] Starting packet capture..." -ForegroundColor Green
Write-Host "[+] Geolocation services: ACTIVE" -ForegroundColor Green
Write-Host "[+] Waiting for WhatsApp call..." -ForegroundColor Yellow

& $tshark -i "WiFi" -Y "stun and ip.src == $localIP" -T fields -e frame.time -e ip.dst | ForEach-Object {
    $currentTime = Get-Date
    $data = $_ -split "\t"
    
    if ($data.Length -ge 2) {
        $ip = $data[1].Trim()
        
        # Enhanced filtering of WhatsApp servers
        $whatsappPatterns = @(
            "157.240.", "203.101.", "31.13.", "69.63.", "179.60.", "185.60.", "129.134.",
            "204.15.", "173.252.", "66.220.", "69.171.", "174.120.", "186.46.", "199.201."
        )
        
        $isWhatsAppServer = $false
        foreach ($pattern in $whatsappPatterns) {
            if ($ip -like "$pattern*") {
                $isWhatsAppServer = $true
                break
            }
        }
        
        if (-not $isWhatsAppServer -and $ip -match '^\d+\.\d+\.\d+\.\d+$') {
            # Track this IP
            if (-not $ipTracker.ContainsKey($ip)) {
                $ipTracker[$ip] = @()
            }
            $ipTracker[$ip] += $currentTime
            
            # If this IP appears multiple times or we haven't processed it, analyze it
            if ($ipTracker[$ip].Count -eq 1 -or (-not $processedIPs.ContainsKey($ip))) {
                Write-Host "`n🎯 POTENTIAL TARGET DETECTED: $ip" -ForegroundColor Green -BackgroundColor Black
                Write-Host "   First seen: $($ipTracker[$ip][0].ToString('HH:mm:ss'))" -ForegroundColor Cyan
                Write-Host "   Occurrences: $($ipTracker[$ip].Count)" -ForegroundColor Cyan
                
                $locationInfo = Get-EnhancedIPInfo -IPAddress $ip
                if ($locationInfo) {
                    Show-EnhancedLocationInfo -locationInfo $locationInfo
                } else {
                    Write-Host "   [Geolocation lookup failed]" -ForegroundColor Red
                }
            }
        }
    }
}