<#
.SYNOPSIS
    Configuration wizard for AD User Management Tool.
    Run this ONCE before using AD-UserManagement.ps1 to generate your config.json.

.NOTES
    Version: 1.0
    Run as Administrator on your management workstation.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configPath = Join-Path $PSScriptRoot "config.json"

$wizForm = New-Object System.Windows.Forms.Form
$wizForm.Text = "AD User Management - Configuration Wizard"
$wizForm.Size = New-Object System.Drawing.Size(620, 520)
$wizForm.StartPosition = "CenterScreen"
$wizForm.FormBorderStyle = "FixedDialog"
$wizForm.MaximizeBox = $false
$wizForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$wizForm.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

# Header
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
$pnlHeader.Size = New-Object System.Drawing.Size(620, 60)
$pnlHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$wizForm.Controls.Add($pnlHeader)

$lblHeader = New-Object System.Windows.Forms.Label
$lblHeader.Text = "AD User Management - Configuration Wizard"
$lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblHeader.ForeColor = [System.Drawing.Color]::White
$lblHeader.Location = New-Object System.Drawing.Point(20, 15)
$lblHeader.AutoSize = $true
$pnlHeader.Controls.Add($lblHeader)

$yPos = 75

function Add-ConfigField {
    param(
        [System.Windows.Forms.Form]$Form, [ref]$Y, [string]$LabelText,
        [string]$DefaultValue = "", [string]$HelpText = "", [int]$TextWidth = 350
    )
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $LabelText
    $lbl.Location = New-Object System.Drawing.Point(20, $Y.Value)
    $lbl.AutoSize = $true
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $Form.Controls.Add($lbl)
    $Y.Value += 20
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, $Y.Value)
    $txt.Size = New-Object System.Drawing.Size($TextWidth, 25)
    $txt.Text = $DefaultValue
    $Form.Controls.Add($txt)
    if ($HelpText) {
        $hlp = New-Object System.Windows.Forms.Label
        $hlp.Text = $HelpText
        $hlp.Location = New-Object System.Drawing.Point(($TextWidth + 30), ($Y.Value + 3))
        $hlp.AutoSize = $true
        $hlp.ForeColor = [System.Drawing.Color]::Gray
        $hlp.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $Form.Controls.Add($hlp)
    }
    $Y.Value += 32
    return $txt
}

# --- Active Directory ---
$lblAD = New-Object System.Windows.Forms.Label
$lblAD.Text = "Active Directory"
$lblAD.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblAD.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$lblAD.Location = New-Object System.Drawing.Point(20, $yPos)
$lblAD.AutoSize = $true
$wizForm.Controls.Add($lblAD)
$yPos += 25

$txtDC = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Domain Controller FQDN:" -HelpText "e.g. DC01.ad.contoso.com"
$txtDomainFQDN = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "AD Domain FQDN (for login):" -HelpText "e.g. ad.contoso.com"
$txtEmailDomain = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Email Domain:" -HelpText "e.g. contoso.com"

# --- OUs ---
$lblOU = New-Object System.Windows.Forms.Label
$lblOU.Text = "Organizational Units"
$lblOU.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblOU.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$lblOU.Location = New-Object System.Drawing.Point(20, $yPos)
$lblOU.AutoSize = $true
$wizForm.Controls.Add($lblOU)
$yPos += 25

$txtStandardOU = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Standard Users OU (DN):" -HelpText "Where active users live" -TextWidth 560
$txtDisabledOU = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Disabled Users OU (DN):" -HelpText "Where disabled users are moved" -TextWidth 560

# --- Security Group ---
$lblGrp = New-Object System.Windows.Forms.Label
$lblGrp.Text = "Security Group Membership (Optional)"
$lblGrp.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblGrp.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$lblGrp.Location = New-Object System.Drawing.Point(20, $yPos)
$lblGrp.AutoSize = $true
$wizForm.Controls.Add($lblGrp)
$yPos += 25

$txtSecGroupDN = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Security Group DN:" -HelpText "Leave blank to disable this tab" -TextWidth 560
$txtSecGroupName = Add-ConfigField -Form $wizForm -Y ([ref]$yPos) -LabelText "Friendly Name for Group:" -HelpText "e.g. VPN Access, CRM Access"

# --- Session ---
$lblTimeout = New-Object System.Windows.Forms.Label
$lblTimeout.Text = "Session Timeout (minutes):"
$lblTimeout.Location = New-Object System.Drawing.Point(20, $yPos)
$lblTimeout.AutoSize = $true
$lblTimeout.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$wizForm.Controls.Add($lblTimeout)

$nudTimeout = New-Object System.Windows.Forms.NumericUpDown
$nudTimeout.Location = New-Object System.Drawing.Point(200, $yPos)
$nudTimeout.Size = New-Object System.Drawing.Size(80, 25)
$nudTimeout.Minimum = 1
$nudTimeout.Maximum = 120
$nudTimeout.Value = 10
$wizForm.Controls.Add($nudTimeout)
$yPos += 40

# Load existing config
if (Test-Path $configPath) {
    try {
        $existing = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($existing.DomainController)     { $txtDC.Text = $existing.DomainController }
        if ($existing.DomainFQDN)            { $txtDomainFQDN.Text = $existing.DomainFQDN }
        if ($existing.EmailDomain)           { $txtEmailDomain.Text = $existing.EmailDomain }
        if ($existing.StandardUsersOU)       { $txtStandardOU.Text = $existing.StandardUsersOU }
        if ($existing.DisabledUsersOU)       { $txtDisabledOU.Text = $existing.DisabledUsersOU }
        if ($existing.SecurityGroupDN)       { $txtSecGroupDN.Text = $existing.SecurityGroupDN }
        if ($existing.SecurityGroupName)     { $txtSecGroupName.Text = $existing.SecurityGroupName }
        if ($existing.SessionTimeoutMinutes) { $nudTimeout.Value = $existing.SessionTimeoutMinutes }
    } catch {}
}

# Buttons
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Configuration"
$btnSave.Location = New-Object System.Drawing.Point(20, $yPos)
$btnSave.Size = New-Object System.Drawing.Size(180, 40)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = "Flat"
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$wizForm.Controls.Add($btnSave)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancel"
$btnCancel.Location = New-Object System.Drawing.Point(210, $yPos)
$btnCancel.Size = New-Object System.Drawing.Size(100, 40)
$btnCancel.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnCancel.ForeColor = [System.Drawing.Color]::White
$btnCancel.FlatStyle = "Flat"
$wizForm.Controls.Add($btnCancel)

$btnCancel.Add_Click({ $wizForm.Close() })

$btnSave.Add_Click({
    $missing = @()
    if (-not $txtDC.Text.Trim())          { $missing += "Domain Controller FQDN" }
    if (-not $txtDomainFQDN.Text.Trim())  { $missing += "AD Domain FQDN" }
    if (-not $txtEmailDomain.Text.Trim()) { $missing += "Email Domain" }
    if (-not $txtStandardOU.Text.Trim())  { $missing += "Standard Users OU" }
    if (-not $txtDisabledOU.Text.Trim())  { $missing += "Disabled Users OU" }
    if ($missing.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Required fields are empty:`n`n- $($missing -join "`n- ")",
            "Validation Error", "OK", "Warning"
        )
        return
    }
    $config = [ordered]@{
        DomainController      = $txtDC.Text.Trim()
        DomainFQDN            = $txtDomainFQDN.Text.Trim()
        EmailDomain           = $txtEmailDomain.Text.Trim()
        StandardUsersOU       = $txtStandardOU.Text.Trim()
        DisabledUsersOU       = $txtDisabledOU.Text.Trim()
        SecurityGroupDN       = $txtSecGroupDN.Text.Trim()
        SecurityGroupName     = $txtSecGroupName.Text.Trim()
        SessionTimeoutMinutes = [int]$nudTimeout.Value
    }
    try {
        $config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show(
            "Configuration saved to:`n$configPath`n`nYou can now run AD-UserManagement.ps1",
            "Success", "OK", "Information"
        )
        $wizForm.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error saving config: $_", "Error", "OK", "Error")
    }
})

[void]$wizForm.ShowDialog()
$wizForm.Dispose()
