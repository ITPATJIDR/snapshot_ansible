# Fix WinRM and CredSSP configuration on Windows Server
# Run this on 192.168.1.215 as Administrator

Write-Host "Fixing WinRM and CredSSP Configuration..." -ForegroundColor Green

# Ensure WinRM is enabled
Write-Host "`n1. Enabling WinRM..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Enable CredSSP Server
Write-Host "`n2. Enabling CredSSP Server..." -ForegroundColor Yellow
try {
    Enable-WSManCredSSP -Role Server -Force
    Write-Host "   CredSSP Server enabled" -ForegroundColor Green
} catch {
    Write-Host "   Warning: $_" -ForegroundColor Yellow
}

# Ensure HTTP listener exists
Write-Host "`n3. Checking/Creating HTTP Listener..." -ForegroundColor Yellow
$httpListener = Get-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"} -ErrorAction SilentlyContinue
if (-not $httpListener) {
    New-WSManInstance -ResourceURI winrm/config/listener -SelectorSet @{Address="*";Transport="HTTP"} -ValueSet @{Enabled="true"}
    Write-Host "   HTTP listener created" -ForegroundColor Green
} else {
    Write-Host "   HTTP listener exists" -ForegroundColor Green
}

# Configure WinRM Service
Write-Host "`n4. Configuring WinRM Service..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\Auth\CredSSP -Value $true
Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true  # For HTTP
Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000

# Configure firewall
Write-Host "`n5. Configuring Firewall..." -ForegroundColor Yellow

# Remove any blocking rules first
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*WinRM*" -and $_.Action -eq 'Block' } | Remove-NetFirewallRule -ErrorAction SilentlyContinue

# Ensure allow rules exist
$httpRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -ErrorAction SilentlyContinue
if (-not $httpRule) {
    New-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" `
        -DisplayName "Windows Remote Management (HTTP-In)" `
        -Protocol TCP -LocalPort 5985 -Action Allow -Enabled True `
        -Profile Any -Direction Inbound
    Write-Host "   HTTP firewall rule created (port 5985)" -ForegroundColor Green
} else {
    Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -Enabled True -Action Allow
    Write-Host "   HTTP firewall rule verified" -ForegroundColor Green
}

# Restart WinRM
Write-Host "`n6. Restarting WinRM Service..." -ForegroundColor Yellow
Restart-Service WinRM -Force
Start-Sleep -Seconds 2

# Test
Write-Host "`n7. Testing Configuration..." -ForegroundColor Yellow
try {
    Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-Null
    Write-Host "   SUCCESS: WinRM is working!" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: WinRM test failed - $_" -ForegroundColor Red
}

# Display current config
Write-Host "`n8. Current Configuration:" -ForegroundColor Cyan
Write-Host "   Listeners:" -ForegroundColor Yellow
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate | ForEach-Object {
    Write-Host "     - $($_.Transport) on port $($_.Port)" -ForegroundColor Green
}

Write-Host "`n   Authentication:" -ForegroundColor Yellow
$auth = Get-WSManInstance -ResourceURI winrm/config/service/auth
Write-Host "     - Basic: $($auth.Basic)" -ForegroundColor Green
Write-Host "     - CredSSP: $($auth.CredSSP)" -ForegroundColor Green
Write-Host "     - Negotiate: $($auth.Negotiate)" -ForegroundColor Green

Write-Host "`n   Firewall Rules:" -ForegroundColor Yellow
Get-NetFirewallRule | Where-Object { 
    $_.DisplayName -like "*WinRM*" -and $_.Enabled -eq $true 
} | ForEach-Object {
    Write-Host "     - $($_.DisplayName) [$($_.Action)]" -ForegroundColor Green
}

Write-Host "`nConfiguration complete! Test from AWX now." -ForegroundColor Green

