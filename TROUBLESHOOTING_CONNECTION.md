# Troubleshooting WinRM Connection Issues

## Your Current Error
```
No route to host - port 5985
```

This means AWX cannot reach port 5985 on 192.168.1.215. This is typically a **firewall or network issue**.

## Step-by-Step Fix

### Step 1: Verify WinRM on Windows Server (192.168.1.215)

**On the Windows Server**, run as Administrator:

```powershell
.\verify-winrm.ps1
```

This will check:
- ✅ WinRM service status
- ✅ Listeners (HTTP/HTTPS)
- ✅ Firewall rules
- ✅ Authentication methods
- ✅ Port availability

### Step 2: Fix WinRM Configuration

**On the Windows Server**, run as Administrator:

```powershell
.\fix-winrm-credssp.ps1
```

This will:
- Enable WinRM
- Enable CredSSP server
- Create HTTP listener on port 5985
- Configure firewall rules
- Allow unencrypted traffic (for HTTP)

### Step 3: Test from AWX Server

**From your AWX/Ansible server**, test network connectivity:

```bash
# Test if port is reachable
nc -zv 192.168.1.215 5985

# OR using telnet
telnet 192.168.1.215 5985

# OR using curl
curl -v http://192.168.1.215:5985/wsman
```

**Expected response:** You should see HTTP headers or connection established.

If this fails, there's a firewall/network issue between AWX and the Windows server.

### Step 4: Check Windows Firewall

**On the Windows Server**:

```powershell
# Check if Windows Firewall is blocking
Get-NetFirewallRule | Where-Object { 
    $_.DisplayName -like "*WinRM*" 
} | Select-Object Name, DisplayName, Enabled, Action

# Make sure there's an enabled Allow rule for port 5985
# If not, run:
New-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" `
    -DisplayName "Windows Remote Management (HTTP-In)" `
    -Protocol TCP -LocalPort 5985 -Action Allow -Enabled True `
    -Profile Any -Direction Inbound
```

### Step 5: Check External Firewall

If there's a network firewall between AWX and Windows server:
- Ensure port 5985 (TCP) is open
- Check router/switch ACLs
- Verify no security groups blocking traffic (if in cloud)

### Step 6: Alternative Configurations

If you still have issues, try these alternative AWX host configurations:

#### Option 1: Use HTTPS (Port 5986) - RECOMMENDED

```json
{
  "ansible_connection": "winrm",
  "ansible_port": 5986,
  "ansible_user": "admin",
  "ansible_password": "123456",
  "ansible_winrm_transport": "ntlm",
  "ansible_winrm_scheme": "https",
  "ansible_winrm_server_cert_validation": "ignore",
  "ansible_winrm_operation_timeout_sec": 60,
  "ansible_winrm_read_timeout_sec": 90
}
```

**On Windows Server**, ensure HTTPS listener exists:
```powershell
.\setup-windows.ps1  # This creates HTTPS listener
```

#### Option 2: Use Basic Auth (Simpler)

```json
{
  "ansible_connection": "winrm",
  "ansible_port": 5985,
  "ansible_user": "admin",
  "ansible_password": "123456",
  "ansible_winrm_transport": "basic",
  "ansible_winrm_scheme": "http",
  "ansible_winrm_server_cert_validation": "ignore",
  "ansible_winrm_operation_timeout_sec": 60,
  "ansible_winrm_read_timeout_sec": 90
}
```

**On Windows Server**:
```powershell
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
```

#### Option 3: Use NTLM (Most Common)

```json
{
  "ansible_connection": "winrm",
  "ansible_port": 5985,
  "ansible_user": "admin",
  "ansible_password": "123456",
  "ansible_winrm_transport": "ntlm",
  "ansible_winrm_scheme": "http",
  "ansible_winrm_server_cert_validation": "ignore",
  "ansible_winrm_operation_timeout_sec": 60,
  "ansible_winrm_read_timeout_sec": 90
}
```

## Common Issues and Solutions

### Issue 1: "No route to host"
**Cause:** Network/firewall blocking connection
**Fix:** 
- Verify port 5985/5986 is open in firewall
- Test with `telnet 192.168.1.215 5985`
- Check Windows Firewall rules

### Issue 2: "Connection refused"
**Cause:** WinRM service not running
**Fix:**
```powershell
Start-Service WinRM
Set-Service WinRM -StartupType Automatic
```

### Issue 3: "Authentication failed"
**Cause:** Wrong credentials or auth method
**Fix:**
- Verify username/password
- Try different `ansible_winrm_transport` (ntlm, basic, credssp)
- Ensure user is Administrator or in "Hyper-V Administrators" group

### Issue 4: CredSSP errors
**Cause:** CredSSP not enabled or requires HTTPS
**Fix:**
```powershell
# On Windows Server
Enable-WSManCredSSP -Role Server -Force

# Or use NTLM instead (simpler)
```

### Issue 5: "Max retries exceeded"
**Cause:** Timeout or wrong port
**Fix:**
- Verify correct port (5985 for HTTP, 5986 for HTTPS)
- Increase timeout values
- Check WinRM is actually listening: `netstat -an | findstr :5985`

## Quick Debug Commands

### On Windows Server:
```powershell
# Check WinRM status
Get-Service WinRM

# Test WinRM locally
Test-WSMan localhost

# Check listeners
Get-WSManInstance -ResourceURI winrm/config/listener -Enumerate

# Check listening ports
netstat -an | findstr :5985
netstat -an | findstr :5986

# Check firewall
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*WinRM*" }

# View WinRM config
winrm get winrm/config
```

### From AWX/Ansible Server:
```bash
# Test port connectivity
nc -zv 192.168.1.215 5985
telnet 192.168.1.215 5985

# Test WinRM endpoint
curl -v http://192.168.1.215:5985/wsman

# Test with Ansible
ansible 192.168.1.215 -i inventory.ini -m win_ping -vvv
```

## Working Configuration (Copy this to your AWX host)

Since you mentioned another task CAN access the server, compare these settings:

**Recommended configuration that usually works:**

```json
{
  "ansible_connection": "winrm",
  "ansible_port": 5986,
  "ansible_user": "admin",
  "ansible_password": "123456",
  "ansible_winrm_transport": "ntlm",
  "ansible_winrm_scheme": "https",
  "ansible_winrm_server_cert_validation": "ignore"
}
```

**Make sure on Windows Server:**
1. WinRM is running
2. HTTPS listener exists (run `.\setup-windows.ps1`)
3. Firewall allows port 5986
4. User has admin rights

## Still Not Working?

1. **Compare with your working task configuration** - What settings does it use?
2. **Check AWX logs** for more detailed error messages
3. **Run from AWX server shell** to rule out AWX-specific issues:
   ```bash
   ansible 192.168.1.215 -i inventory.ini -m win_ping -vvvv
   ```
4. **Disable Windows Firewall temporarily** (for testing):
   ```powershell
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
   ```
   If this works, it's a firewall rule issue.

## Next Steps

1. Run `verify-winrm.ps1` on Windows Server
2. Run `fix-winrm-credssp.ps1` if needed
3. Test connectivity from AWX: `nc -zv 192.168.1.215 5985`
4. Try alternative configurations (HTTPS with NTLM recommended)
5. Check what configuration your working task uses and match it

