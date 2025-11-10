param([string]$Interface = "WiFi", [int]$AnalysisWindow = 30)

$tshark = "C:\Program Files\Wireshark\tshark.exe"
if (-not (Test-Path $tshark)) { throw "tshark not found at $tshark" }

$ipTracker = @{}
$startTime = Get-Date
$localIP = (Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4).IPAddress

Write-Host "Monitoring IP: $localIP"

& $tshark -i $Interface -Y "stun and ip.src == $localIP" -T fields -e frame.time -e ip.dst | ForEach-Object {
    $now = Get-Date
    $data = $_ -split "`t"
    if ($data.Length -ge 2) {
        $ip = $data[1].Trim()
        if ($ip -match '^\d+\.\d+\.\d+\.\d+$') {
            if (-not $ipTracker.ContainsKey($ip)) { $ipTracker[$ip] = @() }
            $ipTracker[$ip] += $now
            Write-Host "Seen $ip at $($now.ToString('HH:mm:ss')) — occurrences: $($ipTracker[$ip].Count)"
            # caller will perform geolocation by invoking Get-EnhancedIPInfo
        }
    }
}
