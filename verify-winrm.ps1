# Run this script on the Windows Server (192.168.1.215) to verify WinRM configuration
# Run as Administrator

Write-Host "=== WinRM Configuration Check ===" -ForegroundColor Cyan

# Check WinRM Service
Write-Host "`n1. Checking WinRM Service Status..." -ForegroundColor Yellow
$winrmService = Get-Service WinRM
Write-Host "   Status: $($winrmService.Status)" -ForegroundColor $(if($winrmService.Status -eq 'Running'){'Green'}else{'Red'})

# Check WinRM Listeners
Write-Host "`n2. Checking WinRM Listeners..." -ForegroundColor Yellow
$listeners = Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate
foreach ($listener in $listeners) {
    Write-Host "   Transport: $($listener.Transport)" -ForegroundColor Green
    Write-Host "   Port: $($listener.Port)" -ForegroundColor Green
    Write-Host "   Address: $($listener.Address)" -ForegroundColor Green
    Write-Host "   ---"
}

if (-not $listeners) {
    Write-Host "   ERROR: No WinRM listeners found!" -ForegroundColor Red
}

# Check Firewall Rules
Write-Host "`n3. Checking Firewall Rules..." -ForegroundColor Yellow
$firewallRules = Get-NetFirewallRule | Where-Object { 
    $_.DisplayName -like "*WinRM*" -or $_.Name -like "*WINRM*" 
} | Select-Object Name, DisplayName, Enabled, Direction, Action

foreach ($rule in $firewallRules) {
    $color = if($rule.Enabled -eq $true -and $rule.Action -eq 'Allow'){'Green'}else{'Yellow'}
    Write-Host "   $($rule.DisplayName): Enabled=$($rule.Enabled), Action=$($rule.Action)" -ForegroundColor $color
}

# Check listening ports
Write-Host "`n4. Checking Listening Ports..." -ForegroundColor Yellow
$listeningPorts = Get-NetTCPConnection | Where-Object { 
    $_.State -eq 'Listen' -and ($_.LocalPort -eq 5985 -or $_.LocalPort -eq 5986)
}

foreach ($port in $listeningPorts) {
    Write-Host "   Port $($port.LocalPort) is LISTENING" -ForegroundColor Green
}

if (-not $listeningPorts) {
    Write-Host "   WARNING: Ports 5985/5986 are NOT listening!" -ForegroundColor Red
}

# Check WinRM Configuration
Write-Host "`n5. WinRM Authentication Methods..." -ForegroundColor Yellow
$authConfig = Get-WSManInstance -ResourceURI winrm/config/service/auth
Write-Host "   Basic: $($authConfig.Basic)" -ForegroundColor $(if($authConfig.Basic -eq 'true'){'Green'}else{'Yellow'})
Write-Host "   Kerberos: $($authConfig.Kerberos)" -ForegroundColor $(if($authConfig.Kerberos -eq 'true'){'Green'}else{'Yellow'})
Write-Host "   Negotiate: $($authConfig.Negotiate)" -ForegroundColor $(if($authConfig.Negotiate -eq 'true'){'Green'}else{'Yellow'})
Write-Host "   CredSSP: $($authConfig.CredSSP)" -ForegroundColor $(if($authConfig.CredSSP -eq 'true'){'Green'}else{'Yellow'})

# Test local WinRM
Write-Host "`n6. Testing Local WinRM Connection..." -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-Null
    Write-Host "   Local WinRM test: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "   Local WinRM test: FAILED - $_" -ForegroundColor Red
}

# Check IP addresses
Write-Host "`n7. Server IP Addresses..." -ForegroundColor Yellow
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | ForEach-Object {
    Write-Host "   $($_.InterfaceAlias): $($_.IPAddress)" -ForegroundColor Green
}

# Test from external
Write-Host "`n8. Testing Remote Access..." -ForegroundColor Yellow
Write-Host "   Run this from your AWX/Ansible server:" -ForegroundColor Cyan
Write-Host "   curl -v http://192.168.1.215:5985/wsman" -ForegroundColor White
Write-Host "   OR" -ForegroundColor Cyan
Write-Host "   telnet 192.168.1.215 5985" -ForegroundColor White

Write-Host "`n=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host "If all checks are green, the issue is likely network/firewall between AWX and this server."
Write-Host "If CredSSP is 'false', run: Enable-WSManCredSSP -Role Server -Force" -ForegroundColor Yellow

