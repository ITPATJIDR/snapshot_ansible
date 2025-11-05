# AWX Connection Troubleshooting Guide

## Issue: "No route to host" or Connection Failures

### Problem Analysis

The error "No route to host" typically means:
1. **Network connectivity issue** - AWX runner cannot reach the Windows host
2. **Firewall blocking** - Windows firewall is blocking WinRM port
3. **Wrong port** - Using incorrect port (5985 vs 5986)
4. **AWX inventory configuration** - Host not properly configured in AWX

### Quick Fixes

#### 1. Verify AWX Can Reach the Host

Run the troubleshooting playbook first:
```bash
ansible-playbook troubleshoot-connection.yml -i inventory.ini
```

Or from AWX, create a job template with `troubleshoot-connection.yml`.

#### 2. Use AWX Inventory Instead of Direct IP

**In AWX:**
- Don't use direct IP in playbook `hosts:` line
- Use the hostname from your AWX inventory
- Example: If your host is named `192.168.1.215` in AWX inventory, use:
  ```yaml
  hosts: all
  # or
  hosts: 192.168.1.215  # Use the AWX inventory hostname
  ```

#### 3. Check AWX Host Variables

In AWX, go to **Inventories** → Your inventory → **Hosts** → Click your host → **Variables**

Ensure these are set correctly:
```json
{
  "ansible_connection": "winrm",
  "ansible_port": 5985,
  "ansible_winrm_transport": "credssp",
  "ansible_winrm_scheme": "http",
  "ansible_winrm_server_cert_validation": "ignore",
  "ansible_winrm_message_encryption": "auto"
}
```

#### 4. Test from Windows Host

On the Windows server (192.168.1.215), verify WinRM is working:

```powershell
# Check WinRM service
Get-Service WinRM

# Check listeners
Get-WSManInstance winrm/config/listener

# Test locally
Test-WSMan localhost

# Check firewall rules
Get-NetFirewallRule -Name "WINRM-*" | Select Name, Enabled, Direction, Action
```

#### 5. Network Connectivity from AWX

If AWX runner is in a different network/subnet, you may need to:
- Add route between networks
- Check if AWX runner can ping the Windows host
- Verify no network ACLs are blocking port 5985/5986

### Common Solutions

#### Solution 1: Use HTTPS Port 5986

If HTTP (5985) is blocked, try HTTPS (5986):

**In AWX Host Variables:**
```json
{
  "ansible_port": 5986,
  "ansible_winrm_scheme": "https",
  "ansible_winrm_server_cert_validation": "ignore"
}
```

**On Windows Host:**
```powershell
# Ensure HTTPS listener exists
Get-WSManInstance winrm/config/listener | Where-Object {$_.Transport -eq "HTTPS"}
```

If it doesn't exist, run `setup-windows.ps1` again.

#### Solution 2: Change Transport Method

Try different transport methods:

**Option A: NTLM (for local accounts)**
```json
{
  "ansible_winrm_transport": "ntlm"
}
```

**Option B: Basic (less secure, but simpler)**
```json
{
  "ansible_winrm_transport": "basic",
  "ansible_winrm_message_encryption": "never"
}
```

#### Solution 3: Fix AWX Runner Network

If AWX runner cannot reach the Windows host:

1. **Check AWX runner network configuration:**
   ```bash
   # From AWX runner (if you have shell access)
   ping 192.168.1.215
   telnet 192.168.1.215 5985
   ```

2. **Check AWX execution environment:**
   - Verify AWX runner is in correct network
   - Check if execution environment has network access
   - Verify custom network configuration in AWX

#### Solution 4: Re-run Setup Script

On Windows host, re-run the setup script:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows.ps1
```

### Step-by-Step AWX Configuration

1. **Create/Edit Inventory:**
   - Go to **Inventories** → **Add** (or edit existing)
   - Name: `Windows Server`
   - Add host: `192.168.1.215`

2. **Configure Host Variables:**
   - Click on host → **Variables** tab
   - Add all connection variables (see above)

3. **Create Credential:**
   - **Credentials** → **Add**
   - Type: `Machine`
   - Name: `Windows Admin`
   - Username: `admin`
   - Password: `123456`

4. **Create Job Template:**
   - Use `hosts: all` or `hosts: 192.168.1.215` (use AWX inventory name)
   - Select correct inventory
   - Select credential
   - Save

5. **Test Connection:**
   - Launch job template
   - Check output for errors

### Debugging Commands

#### From AWX Runner (if accessible):
```bash
# Test port connectivity
nc -zv 192.168.1.215 5985

# Test HTTP connection
curl -v http://192.168.1.215:5985/wsman

# Test with Python
python3 -c "import socket; s=socket.socket(); s.settimeout(5); print('OK' if s.connect_ex(('192.168.1.215', 5985)) == 0 else 'FAILED'); s.close()"
```

#### From Windows Host:
```powershell
# Check what's listening
netstat -an | findstr "5985"
netstat -an | findstr "5986"

# Check WinRM configuration
winrm get winrm/config

# Quick test
winrm quickconfig
```

### AWX-Specific Issues

#### Issue: AWX uses different inventory than expected

**Solution:** Always use AWX inventory hostnames in playbooks, not direct IPs.

#### Issue: Credentials not working

**Solution:** 
1. Verify credential type is `Machine`
2. Check username/password are correct
3. Ensure user has admin rights on Windows host

#### Issue: Connection works locally but not in AWX

**Solution:**
1. AWX runner might be in different network
2. Check AWX execution environment network settings
3. Verify AWX runner can reach the Windows host network

### Still Having Issues?

1. Run `troubleshoot-connection.yml` playbook
2. Check AWX job output for detailed errors
3. Verify Windows host WinRM is configured correctly
4. Test connectivity from AWX runner to Windows host
5. Check firewall rules on both AWX runner and Windows host

### Best Practices

1. **Always use AWX inventory** - Don't hardcode IPs in playbooks
2. **Use HTTPS (5986)** - More secure and often works better
3. **Use AWX credentials** - Never hardcode passwords
4. **Test with troubleshoot playbook first** - Diagnose before running main playbooks
5. **Document working configuration** - Save successful host variables for reference

