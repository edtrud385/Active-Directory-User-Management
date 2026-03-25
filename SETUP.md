# Setup Guide

This guide walks through everything needed to deploy the AD User Management Tool in your environment.

## Prerequisites

Before you begin, confirm:

- [ ] You have a Windows 10/11 or Server 2016+ workstation
- [ ] PowerShell 5.1 or later is installed (`$PSVersionTable.PSVersion` to check)
- [ ] You have network connectivity to your Domain Controller
- [ ] PowerShell Remoting (WinRM) is enabled on the Domain Controller
- [ ] You have an AD account with sufficient permissions (see [Delegation](#step-3-delegate-permissions) below)

### Verifying PowerShell Remoting

From the workstation where the tool will run:

```powershell
Test-WSMan -ComputerName DC01.ad.contoso.com
```

If this fails, WinRM needs to be enabled on the DC. On the DC, run:

```powershell
Enable-PSRemoting -Force
```

## Step 1: Run the Configuration Wizard

```powershell
.\Configure-ADUserMgmt.ps1
```

The wizard prompts for the values described below. It saves everything to `config.json` in the same directory.

### Finding Your OU Distinguished Names

The wizard asks for the Distinguished Names (DNs) of your Standard Users and Disabled Users OUs. If you don't know them:

```powershell
# List all OUs in your domain
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Sort-Object Name

# Search for a specific OU by name
Get-ADOrganizationalUnit -Filter "Name -like '*Users*'" | Select-Object DistinguishedName
```

Example values:
```
Standard Users OU:  OU=Users,OU=Corporate,DC=ad,DC=contoso,DC=com
Disabled Users OU:  OU=Disabled,OU=Corporate,DC=ad,DC=contoso,DC=com
```

### Finding a Security Group DN

If you want to use the Security Group tab:

```powershell
Get-ADGroup -Identity "YourGroupName" | Select-Object DistinguishedName
```

Leave the Security Group DN blank in the wizard to hide this tab entirely.

### Configuration Fields

| Field | Required | Example |
|-------|----------|---------|
| Domain Controller FQDN | Yes | `DC01.ad.contoso.com` |
| AD Domain FQDN | Yes | `ad.contoso.com` |
| Email Domain | Yes | `contoso.com` |
| Standard Users OU | Yes | `OU=Users,DC=ad,DC=contoso,DC=com` |
| Disabled Users OU | Yes | `OU=Disabled,DC=ad,DC=contoso,DC=com` |
| Security Group DN | No | `CN=VPN-Access,OU=Groups,DC=ad,DC=contoso,DC=com` |
| Security Group Name | No | `VPN Access` |
| Session Timeout | No | `10` (minutes) |

## Step 2: Create a Delegation Group

Create a dedicated security group for users who will operate this tool. Do not rely on Domain Admins for day-to-day helpdesk work.

```powershell
New-ADGroup -Name "Helpdesk-UserManagement" `
    -GroupScope Global `
    -GroupCategory Security `
    -Path "OU=Groups,DC=ad,DC=contoso,DC=com" `
    -Description "Members can use the AD User Management Tool"
```

Add your helpdesk staff:

```powershell
Add-ADGroupMember -Identity "Helpdesk-UserManagement" -Members jsmith, mjohnson
```

## Step 3: Delegate Permissions

Delegation grants the minimum AD rights needed for the tool to function. This follows the principle of least privilege rather than making helpdesk staff Domain Admins.

### Option A: Delegate via GUI (ADUC)

1. Open **Active Directory Users and Computers**
2. Right-click your **Standard Users OU** and select **Delegate Control**
3. Add the `Helpdesk-UserManagement` group
4. Select **Create a custom task to delegate**
5. Select **Only the following objects in the folder** then check **User objects**
6. Check the following permissions:
   - Create selected objects in this folder
   - Delete selected objects in this folder
   - Read All Properties
   - Write All Properties
   - Reset Password
   - Change Password
7. Click **Finish**
8. **Repeat** for your **Disabled Users OU** (needed for enable/disable moves)

### Option B: Delegate via PowerShell

```powershell
# Variables - adjust to your environment
$StandardOU = "OU=Users,DC=ad,DC=contoso,DC=com"
$DisabledOU = "OU=Disabled,DC=ad,DC=contoso,DC=com"
$Group      = "Helpdesk-UserManagement"

# Get the group SID
$GroupSID = (Get-ADGroup $Group).SID

# Get the GUIDs for User object class and common attributes
$SchemaPath = (Get-ADRootDSE).schemaNamingContext
$UserGUID   = (Get-ADObject -SearchBase $SchemaPath -Filter "Name -eq 'user'" -Properties schemaIDGUID).schemaIDGUID

# Import the AD module for the ACL cmdlets
Import-Module ActiveDirectory

# Function to set delegation on an OU
function Set-OUDelegation {
    param([string]$OU, [System.Security.Principal.SecurityIdentifier]$SID)
    
    $ACL = Get-Acl "AD:\$OU"
    
    # Create User objects
    $ACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
        $SID, "CreateChild,DeleteChild", "Allow", $UserGUID, "All"))
    
    # Read/Write all properties on User objects
    $ACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
        $SID, "GenericRead", "Allow", "Descendents", $UserGUID))
    $ACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
        $SID, "GenericWrite", "Allow", "Descendents", $UserGUID))
    
    # Reset Password
    $ResetPwdGUID = [GUID]"00299570-246d-11d0-a768-00aa006e0529"
    $ACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
        $SID, "ExtendedRight", "Allow", $ResetPwdGUID, "Descendents", $UserGUID))
    
    Set-Acl "AD:\$OU" $ACL
    Write-Host "Delegation set on $OU"
}

Set-OUDelegation -OU $StandardOU -SID $GroupSID
Set-OUDelegation -OU $DisabledOU -SID $GroupSID
```

### Security Group Delegation

If you use the Security Group tab, the delegation group also needs permission to modify membership on that specific group:

```powershell
$TargetGroup = "CN=VPN-Access,OU=Groups,DC=ad,DC=contoso,DC=com"
$DelegationGroup = "Helpdesk-UserManagement"
$DelegationSID = (Get-ADGroup $DelegationGroup).SID

$ACL = Get-Acl "AD:\$TargetGroup"

# Write Members attribute
$MemberGUID = [GUID]"bf9679c0-0de6-11d0-a285-00aa003049e2"
$ACL.AddAccessRule((New-Object System.DirectoryServices.ActiveDirectoryAccessRule `
    $DelegationSID, "WriteProperty", "Allow", $MemberGUID, "None"))

Set-Acl "AD:\$TargetGroup" $ACL
Write-Host "Group membership delegation set"
```

### Move Objects Between OUs

The disable/enable functions move user objects between OUs. This requires **Delete** on the source OU and **Create** on the destination OU, which the delegation above already covers. If you delegated using the GUI and only selected "User objects," this should work. If moves fail, verify that both OUs have Create and Delete rights for User objects.

## Step 4: (Optional) Restrict Who Can Launch the Tool

The tool's login screen validates domain credentials but does not check group membership. To prevent unauthorized users from even opening the tool, add this block to the top of `AD-UserManagement.ps1`, right after the two `Add-Type` lines and before the config loader:

```powershell
# ============================================================================
# LAUNCH RESTRICTION - Only members of this group can run the tool
# ============================================================================
$requiredGroup = "Helpdesk-UserManagement"  # Change to your group name
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)

# Check for group membership (works with nested groups)
$isMember = $false
try {
    $group = [ADSI]"WinNT://$env:USERDOMAIN/$requiredGroup,group"
    $groupSID = (New-Object System.Security.Principal.SecurityIdentifier(
        $group.objectSid[0], 0
    )).Value
    $isMember = $principal.IsInRole($groupSID)
} catch {
    # Fallback: check via AD module if available
    try {
        $adGroups = (whoami /groups /fo csv | ConvertFrom-Csv).'Group Name'
        $isMember = $adGroups -contains "$env:USERDOMAIN\$requiredGroup"
    } catch {
        $isMember = $false
    }
}

if (-not $isMember) {
    [System.Windows.Forms.MessageBox]::Show(
        "You are not authorized to run this tool.`n`nAccess is restricted to members of '$requiredGroup'.`nContact your IT administrator for access.",
        "Access Denied", "OK", "Error"
    )
    exit
}
```

## Step 5: Launch the Tool

```powershell
.\AD-UserManagement.ps1
```

1. The login screen appears. Sign in with your domain credentials.
2. The tool connects to the Domain Controller and loads the user list.
3. Use the tabs to manage users, create new accounts, or manage group membership.

## Distributing the Tool

To deploy to helpdesk workstations:

1. Copy `AD-UserManagement.ps1` and `Configure-ADUserMgmt.ps1` to a shared location or install locally
2. Run `Configure-ADUserMgmt.ps1` once on each workstation (or copy a pre-built `config.json`)
3. Create a shortcut to launch:
   ```
   Target:    powershell.exe -ExecutionPolicy Bypass -File "C:\Tools\AD-UserManagement.ps1"
   Start in:  C:\Tools
   ```

If your environment uses a restrictive execution policy, the shortcut above handles it. Alternatively, sign the scripts with a code signing certificate.

## Troubleshooting

**"config.json not found"**
Run `Configure-ADUserMgmt.ps1` first. The config file must be in the same directory as the main script.

**"Error connecting to Domain Controller"**
- Verify the DC FQDN in config.json is correct: `nslookup DC01.ad.contoso.com`
- Verify PS Remoting: `Test-WSMan -ComputerName DC01.ad.contoso.com`
- Verify your account has remoting access: `Enter-PSSession -ComputerName DC01.ad.contoso.com`

**"Access Denied" on AD operations**
Your account does not have delegated rights on the target OU. See [Step 3](#step-3-delegate-permissions).

**Users not appearing in the list**
The tool queries only the OU specified in `StandardUsersOU` (or `DisabledUsersOU` when the checkbox is checked). Users in other OUs will not appear. Verify the OU DN in your config.

**Security Group tab is missing**
The tab is hidden when `SecurityGroupDN` is blank in `config.json`. Re-run the configuration wizard to set it.

**"Invalid username or password" at login**
The tool authenticates against the domain specified in `DomainFQDN`. Verify this matches your AD domain (e.g. `ad.contoso.com`, not just `contoso.com`).
