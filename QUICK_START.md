# Quick Start Guide - Hyper-V Snapshots with AWX

## 5-Minute Setup

### Step 1: Prepare Your Hyper-V Host (2 minutes)

On your Hyper-V server, open PowerShell as Administrator and run:

```powershell
# Download and run the setup script
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\setup-windows.ps1
```

Note the IP address displayed at the end!

### Step 2: Configure Inventory (1 minute)

Edit `inventory.ini` and replace with your host IP:

```ini
[hyperv_hosts]
my-hyperv ansible_host=YOUR_HOST_IP_HERE

[hyperv_hosts:vars]
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
ansible_port=5986
ansible_user=Administrator
ansible_password=YourPassword123
```

### Step 3: Install Dependencies (1 minute)

```bash
ansible-galaxy collection install -r requirements.yml
pip install -r requirements.txt
```

### Step 4: Test Connection (30 seconds)

```bash
ansible-playbook test-connection.yml
```

If you see "SUCCESS", you're ready to go!

### Step 5: Create Your First Snapshot (30 seconds)

```bash
ansible-playbook snapshot-hyperv.yml
```

Done! Your VMs now have snapshots.

## AWX Setup (Additional 10 minutes)

### 1. Create Project in AWX

- **Projects** → **Add**
- Name: `Hyper-V Snapshots`
- SCM Type: Manual (or Git if in repo)
- Project Path: `/path/to/this/folder`

### 2. Create Inventory

- **Inventories** → **Add**
- Name: `Hyper-V Hosts`
- **Sources** → **Add** → Choose project's `inventory.ini`

### 3. Add Credentials

- **Credentials** → **Add**
- Name: `Hyper-V Admin`
- Type: **Machine**
- Username: `Administrator`
- Password: `YourPassword123`

### 4. Create Job Template

- **Templates** → **Add Job Template**
- Name: `Create Hyper-V Snapshots`
- Inventory: `Hyper-V Hosts`
- Project: `Hyper-V Snapshots`
- Playbook: `snapshot-hyperv.yml`
- Credentials: `Hyper-V Admin`
- **Save**

### 5. Run It!

Click **Launch** 🚀

## Common Commands

```bash
# Create snapshots for all VMs
ansible-playbook snapshot-hyperv.yml

# Create snapshots for specific VMs
ansible-playbook snapshot-hyperv.yml -e '{"vm_names": ["VM1", "VM2"]}'

# List all snapshots
ansible-playbook list-snapshots.yml

# List snapshots for one VM
ansible-playbook list-snapshots.yml -e "vm_name=MyVM"

# Restore from snapshot
ansible-playbook restore-snapshot.yml -e "vm_name=MyVM" -e "snapshot_name=AWX_Snapshot_2025-11-05_10-30-00"

# Delete a snapshot
ansible-playbook delete-snapshot.yml -e "vm_name=MyVM" -e "snapshot_name=AWX_Snapshot_2025-11-05_10-30-00"

# Test connection
ansible-playbook test-connection.yml
```

## Troubleshooting

### Can't connect?

```bash
# Try with verbose output
ansible hyperv_hosts -m win_ping -vvv

# Check if WinRM is running on host
Test-WSMan -ComputerName YOUR_HOST_IP
```

### Permission denied?

Make sure the user is an Administrator or in "Hyper-V Administrators" group:

```powershell
# On Hyper-V host
Add-LocalGroupMember -Group "Hyper-V Administrators" -Member "YourUser"
```

### Timeout?

Increase timeout in `ansible.cfg`:

```ini
[defaults]
timeout = 60
```

## Next Steps

- Read the full [README.md](README.md) for advanced configuration
- Set up scheduled snapshot jobs in AWX
- Create a cleanup playbook for old snapshots
- Configure multiple environments (prod/staging)

## Need Help?

1. Run `ansible-playbook test-connection.yml` to diagnose issues
2. Check the Troubleshooting section in README.md
3. Review logs in AWX for detailed error messages

---

**Pro Tip**: In AWX, create a Survey for the job template to make it easy for non-technical users to create snapshots with a simple form! 📋

