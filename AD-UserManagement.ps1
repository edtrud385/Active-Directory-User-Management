Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================================
# LOAD CONFIGURATION FROM config.json
# ============================================================================
$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "config.json not found.`n`nPlease run Configure-ADUserMgmt.ps1 first.",
        "Configuration Missing", "OK", "Error"
    )
    exit
}
try {
    $jsonConfig = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    [System.Windows.Forms.MessageBox]::Show("Error reading config.json: $_", "Configuration Error", "OK", "Error")
    exit
}
$Config = @{
    DomainController      = $jsonConfig.DomainController
    DomainFQDN            = $jsonConfig.DomainFQDN
    StandardUsersOU       = $jsonConfig.StandardUsersOU
    DisabledUsersOU       = $jsonConfig.DisabledUsersOU
    SecurityGroupDN       = $jsonConfig.SecurityGroupDN
    SecurityGroupName     = if ($jsonConfig.SecurityGroupName) { $jsonConfig.SecurityGroupName } else { "Security Group" }
    EmailDomain           = $jsonConfig.EmailDomain
    SessionTimeoutMinutes = if ($jsonConfig.SessionTimeoutMinutes) { $jsonConfig.SessionTimeoutMinutes } else { 10 }
}

# ============================================================================
# AUTHENTICATION FUNCTIONS
# ============================================================================

function Test-DomainCredentials {
    param(
        [string]$Username,
        [string]$Password,
        [string]$Domain
    )
    
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    
    try {
        $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
        $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($contextType, $Domain)
        $result = $context.ValidateCredentials($Username, $Password)
        $context.Dispose()
        return $result
    }
    catch {
        return $false
    }
}

function Show-LoginForm {
    param([bool]$IsTimeout = $false)
    
    $loginForm = New-Object System.Windows.Forms.Form
    $loginForm.Text = "AD User Management - Login"
    $loginForm.Size = New-Object System.Drawing.Size(420, 380)
    $loginForm.StartPosition = "CenterScreen"
    $loginForm.FormBorderStyle = "FixedDialog"
    $loginForm.MaximizeBox = $false
    $loginForm.MinimizeBox = $false
    $loginForm.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $loginForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Header Panel
    $pnlHeader = New-Object System.Windows.Forms.Panel
    $pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
    $pnlHeader.Size = New-Object System.Drawing.Size(420, 80)
    $pnlHeader.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $loginForm.Controls.Add($pnlHeader)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Active Directory User Management"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15)
    $lblTitle.AutoSize = $true
    $pnlHeader.Controls.Add($lblTitle)
    
    $lblSubtitle = New-Object System.Windows.Forms.Label
    $lblSubtitle.Text = "Sign in with your domain credentials"
    $lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
    $lblSubtitle.Location = New-Object System.Drawing.Point(20, 45)
    $lblSubtitle.AutoSize = $true
    $pnlHeader.Controls.Add($lblSubtitle)
    
    # Lock Icon
    $lblLock = New-Object System.Windows.Forms.Label
    $lblLock.Text = [char]0x26BF
    $lblLock.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24)
    $lblLock.ForeColor = [System.Drawing.Color]::White
    $lblLock.Location = New-Object System.Drawing.Point(350, 20)
    $lblLock.AutoSize = $true
    $pnlHeader.Controls.Add($lblLock)
    
    if ($IsTimeout) {
        $lblTimeout = New-Object System.Windows.Forms.Label
        $lblTimeout.Text = "Session timed out. Please sign in again."
        $lblTimeout.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $lblTimeout.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
        $lblTimeout.Location = New-Object System.Drawing.Point(20, 95)
        $lblTimeout.AutoSize = $true
        $loginForm.Controls.Add($lblTimeout)
    }
    
    $yStart = if ($IsTimeout) { 125 } else { 105 }
    
    $lblUsername = New-Object System.Windows.Forms.Label
    $lblUsername.Text = "Username:"
    $lblUsername.Location = New-Object System.Drawing.Point(40, $yStart)
    $lblUsername.AutoSize = $true
    $loginForm.Controls.Add($lblUsername)
    
    $txtLoginUser = New-Object System.Windows.Forms.TextBox
    $txtLoginUser.Location = New-Object System.Drawing.Point(40, ($yStart + 22))
    $txtLoginUser.Size = New-Object System.Drawing.Size(320, 28)
    $txtLoginUser.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $txtLoginUser.Text = $env:USERNAME
    $loginForm.Controls.Add($txtLoginUser)
    
    $lblDomainHint = New-Object System.Windows.Forms.Label
    $lblDomainHint.Text = "@$($Config.EmailDomain)"
    $lblDomainHint.ForeColor = [System.Drawing.Color]::Gray
    $lblDomainHint.Location = New-Object System.Drawing.Point(40, ($yStart + 52))
    $lblDomainHint.AutoSize = $true
    $loginForm.Controls.Add($lblDomainHint)
    
    $lblPassword = New-Object System.Windows.Forms.Label
    $lblPassword.Text = "Password:"
    $lblPassword.Location = New-Object System.Drawing.Point(40, ($yStart + 75))
    $lblPassword.AutoSize = $true
    $loginForm.Controls.Add($lblPassword)
    
    $txtLoginPass = New-Object System.Windows.Forms.TextBox
    $txtLoginPass.Location = New-Object System.Drawing.Point(40, ($yStart + 97))
    $txtLoginPass.Size = New-Object System.Drawing.Size(320, 28)
    $txtLoginPass.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $txtLoginPass.PasswordChar = [char]0x2022
    $loginForm.Controls.Add($txtLoginPass)
    
    $lblError = New-Object System.Windows.Forms.Label
    $lblError.Text = ""
    $lblError.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
    $lblError.Location = New-Object System.Drawing.Point(40, ($yStart + 130))
    $lblError.Size = New-Object System.Drawing.Size(320, 20)
    $loginForm.Controls.Add($lblError)
    
    $btnSignIn = New-Object System.Windows.Forms.Button
    $btnSignIn.Text = "Sign In"
    $btnSignIn.Location = New-Object System.Drawing.Point(40, ($yStart + 155))
    $btnSignIn.Size = New-Object System.Drawing.Size(320, 40)
    $btnSignIn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $btnSignIn.ForeColor = [System.Drawing.Color]::White
    $btnSignIn.FlatStyle = "Flat"
    $btnSignIn.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnSignIn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $loginForm.Controls.Add($btnSignIn)
    
    $loginForm.AcceptButton = $btnSignIn
    
    $script:LoginSuccess = $false
    $script:AuthenticatedUser = $null
    $loginForm.Tag = "CANCELLED"
    
    $btnSignIn.Add_Click({
        $btnSignIn.Enabled = $false
        $btnSignIn.Text = "Verifying..."
        $loginForm.Refresh()
        
        $username = $txtLoginUser.Text.Trim()
        $password = $txtLoginPass.Text
        
        if (-not $username -or -not $password) {
            $lblError.Text = "Please enter username and password."
            $btnSignIn.Enabled = $true
            $btnSignIn.Text = "Sign In"
            return
        }
        
        $isValid = Test-DomainCredentials -Username $username -Password $password -Domain $Config.DomainFQDN
        
        if ($isValid) {
            $script:LoginSuccess = $true
            $script:AuthenticatedUser = $username
            $loginForm.Tag = "SUCCESS"
            $loginForm.Close()
        }
        else {
            $lblError.Text = "Invalid username or password."
            $txtLoginPass.Text = ""
            $txtLoginPass.Focus()
            $btnSignIn.Enabled = $true
            $btnSignIn.Text = "Sign In"
        }
    })
    
    $txtLoginPass.Focus()
    [void]$loginForm.ShowDialog()
    
    if ($loginForm.Tag -ne "SUCCESS") {
        $script:LoginSuccess = $false
    }
    
    $loginForm.Dispose()
    return $script:LoginSuccess
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($script:txtLog) {
        $script:txtLog.AppendText("$logEntry`r`n")
        $script:txtLog.ScrollToCaret()
    }
}

function Get-ADUsersList {
    param([string]$SearchBase = $Config.StandardUsersOU, [bool]$IncludeDisabled = $false)
    try {
        $users = Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
            param($SearchBase, $IncludeDisabled)
            Import-Module ActiveDirectory
            $filter = if ($IncludeDisabled) { "*" } else { "Enabled -eq `$true" }
            Get-ADUser -Filter $filter -SearchBase $SearchBase -Properties `
                DisplayName, Title, Department, Manager, telephoneNumber, mail, proxyAddresses, Enabled, MemberOf, UserPrincipalName |
            Select-Object SamAccountName, DisplayName, GivenName, Surname, Title, Department, 
                telephoneNumber, mail, proxyAddresses, Enabled, DistinguishedName, MemberOf, UserPrincipalName |
                Sort-Object DisplayName
        } -ArgumentList $SearchBase, $IncludeDisabled
        return $users
    }
    catch {
        Write-Log "Error loading users: $_" "ERROR"
        return @()
    }
}

function Generate-SecurePassword {
    param([int]$Length = 12)
    $chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%"
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

function Set-Progress {
    param([int]$Percent, [string]$Status = "")
    if ($script:progressBar -and $script:lblProgress) {
        $script:progressBar.Value = [Math]::Min(100, [Math]::Max(0, $Percent))
        if ($Status) { $script:lblProgress.Text = $Status }
        if ($script:form) { $script:form.Refresh() }
    }
}

function Reset-Progress {
    if ($script:progressBar -and $script:lblProgress) {
        $script:progressBar.Value = 0
        $script:lblProgress.Text = "Ready"
        if ($script:form) { $script:form.Refresh() }
    }
}

function Refresh-UserList {
    Set-Progress -Percent 10 -Status "Loading..."
    $script:lstUsers.Items.Clear()
    $searchBase = if ($script:chkShowDisabled.Checked) { 
        $Config.DisabledUsersOU 
    } else { 
        $Config.StandardUsersOU 
    }
    
    Set-Progress -Percent 30 -Status "Querying AD..."
    $users = Get-ADUsersList -SearchBase $searchBase -IncludeDisabled $script:chkShowDisabled.Checked
    
    Set-Progress -Percent 70 -Status "Populating..."
    $totalUsers = $users.Count
    $i = 0
    foreach ($user in $users) {
        $status = if ($user.Enabled) { "Active" } else { "Disabled" }
        $item = New-Object System.Windows.Forms.ListViewItem($user.SamAccountName)
        $item.SubItems.Add([string]$user.DisplayName)
        $item.SubItems.Add([string]$user.Title)
        $item.SubItems.Add($status)
        $item.Tag = $user
        $script:lstUsers.Items.Add($item)
        $i++
        if ($i % 10 -eq 0) {
            $pct = 70 + [int](($i / $totalUsers) * 30)
            Set-Progress -Percent $pct -Status "Loading $i/$totalUsers"
        }
    }
    Reset-Progress
    Write-Log "Refreshed user list: $($users.Count) users found"
}

function Reset-InactivityTimer {
    if ($script:inactivityTimer) {
        $script:inactivityTimer.Stop()
        $script:inactivityTimer.Start()
    }
}

# ============================================================================
# SHOW LOGIN FIRST
# ============================================================================

$loginResult = Show-LoginForm -IsTimeout $false
if ((-not $loginResult) -or (-not $script:LoginSuccess)) {
    throw "Login cancelled"
}

# ============================================================================
# MAIN FORM
# ============================================================================

$script:form = New-Object System.Windows.Forms.Form
$form.Text = "AD User Management v1.0 [$($script:AuthenticatedUser)]"
$form.Size = New-Object System.Drawing.Size(1000, 750)
$form.MinimumSize = New-Object System.Drawing.Size(900, 650)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

# ============================================================================
# INACTIVITY TIMER
# ============================================================================

$script:inactivityTimer = New-Object System.Windows.Forms.Timer
$script:inactivityTimer.Interval = $Config.SessionTimeoutMinutes * 60 * 1000
$script:inactivityTimer.Add_Tick({
    $script:inactivityTimer.Stop()
    $form.Hide()
    
    $reauth = Show-LoginForm -IsTimeout $true
    
    if ($reauth) {
        $form.Show()
        $script:inactivityTimer.Start()
        Write-Log "Session resumed after re-authentication"
    }
    else {
        $form.Close()
    }
})

$form.Add_MouseMove({ Reset-InactivityTimer })
$form.Add_KeyPress({ Reset-InactivityTimer })
$form.Add_Click({ Reset-InactivityTimer })

# Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(965, 550)
$tabControl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$tabControl.Add_SelectedIndexChanged({ Reset-InactivityTimer })

# ============================================================================
# TAB 1: USER LIST & MANAGEMENT
# ============================================================================

$tabUsers = New-Object System.Windows.Forms.TabPage
$tabUsers.Text = "User Management"
$tabUsers.BackColor = [System.Drawing.Color]::White

# Search Panel
$pnlSearch = New-Object System.Windows.Forms.Panel
$pnlSearch.Location = New-Object System.Drawing.Point(10, 10)
$pnlSearch.Size = New-Object System.Drawing.Size(940, 40)

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "Search:"
$lblSearch.Location = New-Object System.Drawing.Point(0, 10)
$lblSearch.AutoSize = $true
$pnlSearch.Controls.Add($lblSearch)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = New-Object System.Drawing.Point(55, 7)
$txtSearch.Size = New-Object System.Drawing.Size(200, 25)
$txtSearch.Add_TextChanged({ Reset-InactivityTimer })
$pnlSearch.Controls.Add($txtSearch)

$script:chkShowDisabled = New-Object System.Windows.Forms.CheckBox
$chkShowDisabled.Text = "Show Disabled Users"
$chkShowDisabled.Location = New-Object System.Drawing.Point(270, 8)
$chkShowDisabled.AutoSize = $true
$pnlSearch.Controls.Add($chkShowDisabled)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(420, 5)
$btnRefresh.Size = New-Object System.Drawing.Size(80, 28)
$btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$btnRefresh.ForeColor = [System.Drawing.Color]::White
$btnRefresh.FlatStyle = "Flat"
$pnlSearch.Controls.Add($btnRefresh)

$tabUsers.Controls.Add($pnlSearch)

# User ListView
$script:lstUsers = New-Object System.Windows.Forms.ListView
$lstUsers.Location = New-Object System.Drawing.Point(10, 55)
$lstUsers.Size = New-Object System.Drawing.Size(600, 350)
$lstUsers.View = "Details"
$lstUsers.FullRowSelect = $true
$lstUsers.GridLines = $true
$lstUsers.Columns.Add("Username", 120)
$lstUsers.Columns.Add("Display Name", 180)
$lstUsers.Columns.Add("Title", 150)
$lstUsers.Columns.Add("Status", 80)
$lstUsers.Add_Click({ Reset-InactivityTimer })
$tabUsers.Controls.Add($lstUsers)

# Action Buttons Panel
$pnlActions = New-Object System.Windows.Forms.Panel
$pnlActions.Location = New-Object System.Drawing.Point(620, 55)
$pnlActions.Size = New-Object System.Drawing.Size(330, 350)
$pnlActions.BorderStyle = "FixedSingle"

$lblActions = New-Object System.Windows.Forms.Label
$lblActions.Text = "Actions"
$lblActions.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblActions.Location = New-Object System.Drawing.Point(10, 10)
$lblActions.AutoSize = $true
$pnlActions.Controls.Add($lblActions)

$btnResetPassword = New-Object System.Windows.Forms.Button
$btnResetPassword.Text = "Reset Password"
$btnResetPassword.Location = New-Object System.Drawing.Point(10, 45)
$btnResetPassword.Size = New-Object System.Drawing.Size(150, 35)
$btnResetPassword.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$btnResetPassword.ForeColor = [System.Drawing.Color]::White
$btnResetPassword.FlatStyle = "Flat"
$pnlActions.Controls.Add($btnResetPassword)

$btnDisableUser = New-Object System.Windows.Forms.Button
$btnDisableUser.Text = "Disable User"
$btnDisableUser.Location = New-Object System.Drawing.Point(165, 45)
$btnDisableUser.Size = New-Object System.Drawing.Size(150, 35)
$btnDisableUser.BackColor = [System.Drawing.Color]::FromArgb(209, 52, 56)
$btnDisableUser.ForeColor = [System.Drawing.Color]::White
$btnDisableUser.FlatStyle = "Flat"
$pnlActions.Controls.Add($btnDisableUser)

$btnEnableUser = New-Object System.Windows.Forms.Button
$btnEnableUser.Text = "Enable User"
$btnEnableUser.Location = New-Object System.Drawing.Point(10, 85)
$btnEnableUser.Size = New-Object System.Drawing.Size(150, 35)
$btnEnableUser.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
$btnEnableUser.ForeColor = [System.Drawing.Color]::White
$btnEnableUser.FlatStyle = "Flat"
$pnlActions.Controls.Add($btnEnableUser)

$btnEditUser = New-Object System.Windows.Forms.Button
$btnEditUser.Text = "Edit User"
$btnEditUser.Location = New-Object System.Drawing.Point(165, 85)
$btnEditUser.Size = New-Object System.Drawing.Size(150, 35)
$btnEditUser.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnEditUser.ForeColor = [System.Drawing.Color]::White
$btnEditUser.FlatStyle = "Flat"
$pnlActions.Controls.Add($btnEditUser)

# Selected User Info
$lblSelectedUser = New-Object System.Windows.Forms.Label
$lblSelectedUser.Text = "Selected User Details:"
$lblSelectedUser.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblSelectedUser.Location = New-Object System.Drawing.Point(10, 135)
$lblSelectedUser.AutoSize = $true
$pnlActions.Controls.Add($lblSelectedUser)

$txtUserDetails = New-Object System.Windows.Forms.TextBox
$txtUserDetails.Location = New-Object System.Drawing.Point(10, 160)
$txtUserDetails.Size = New-Object System.Drawing.Size(305, 175)
$txtUserDetails.Multiline = $true
$txtUserDetails.ReadOnly = $true
$txtUserDetails.ScrollBars = "Vertical"
$txtUserDetails.Font = New-Object System.Drawing.Font("Consolas", 9)
$pnlActions.Controls.Add($txtUserDetails)

$tabUsers.Controls.Add($pnlActions)

$tabControl.TabPages.Add($tabUsers)

# ============================================================================
# TAB 2: CREATE NEW USER
# ============================================================================

$tabCreate = New-Object System.Windows.Forms.TabPage
$tabCreate.Text = "Create New User"
$tabCreate.BackColor = [System.Drawing.Color]::White

# User Info Panel
$pnlUserInfo = New-Object System.Windows.Forms.GroupBox
$pnlUserInfo.Text = "User Information"
$pnlUserInfo.Location = New-Object System.Drawing.Point(10, 10)
$pnlUserInfo.Size = New-Object System.Drawing.Size(450, 280)

$lblFirstName = New-Object System.Windows.Forms.Label
$lblFirstName.Text = "First Name: *"
$lblFirstName.Location = New-Object System.Drawing.Point(15, 30)
$lblFirstName.AutoSize = $true
$pnlUserInfo.Controls.Add($lblFirstName)

$txtFirstName = New-Object System.Windows.Forms.TextBox
$txtFirstName.Location = New-Object System.Drawing.Point(120, 27)
$txtFirstName.Size = New-Object System.Drawing.Size(150, 25)
$txtFirstName.Add_TextChanged({ Reset-InactivityTimer })
$pnlUserInfo.Controls.Add($txtFirstName)

$lblLastName = New-Object System.Windows.Forms.Label
$lblLastName.Text = "Last Name: *"
$lblLastName.Location = New-Object System.Drawing.Point(15, 60)
$lblLastName.AutoSize = $true
$pnlUserInfo.Controls.Add($lblLastName)

$txtLastName = New-Object System.Windows.Forms.TextBox
$txtLastName.Location = New-Object System.Drawing.Point(120, 57)
$txtLastName.Size = New-Object System.Drawing.Size(150, 25)
$txtLastName.Add_TextChanged({ Reset-InactivityTimer })
$pnlUserInfo.Controls.Add($txtLastName)

$lblUsername = New-Object System.Windows.Forms.Label
$lblUsername.Text = "Username:"
$lblUsername.Location = New-Object System.Drawing.Point(15, 90)
$lblUsername.AutoSize = $true
$pnlUserInfo.Controls.Add($lblUsername)

$txtUsername = New-Object System.Windows.Forms.TextBox
$txtUsername.Location = New-Object System.Drawing.Point(120, 87)
$txtUsername.Size = New-Object System.Drawing.Size(150, 25)
$txtUsername.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 200)
$pnlUserInfo.Controls.Add($txtUsername)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Title:"
$lblTitle.Location = New-Object System.Drawing.Point(15, 120)
$lblTitle.AutoSize = $true
$pnlUserInfo.Controls.Add($lblTitle)

$txtTitle = New-Object System.Windows.Forms.TextBox
$txtTitle.Location = New-Object System.Drawing.Point(120, 117)
$txtTitle.Size = New-Object System.Drawing.Size(200, 25)
$pnlUserInfo.Controls.Add($txtTitle)

$lblDepartment = New-Object System.Windows.Forms.Label
$lblDepartment.Text = "Department:"
$lblDepartment.Location = New-Object System.Drawing.Point(15, 150)
$lblDepartment.AutoSize = $true
$pnlUserInfo.Controls.Add($lblDepartment)

$txtDepartment = New-Object System.Windows.Forms.TextBox
$txtDepartment.Location = New-Object System.Drawing.Point(120, 147)
$txtDepartment.Size = New-Object System.Drawing.Size(200, 25)
$pnlUserInfo.Controls.Add($txtDepartment)

$lblPhone = New-Object System.Windows.Forms.Label
$lblPhone.Text = "Phone:"
$lblPhone.Location = New-Object System.Drawing.Point(15, 180)
$lblPhone.AutoSize = $true
$pnlUserInfo.Controls.Add($lblPhone)

$txtPhone = New-Object System.Windows.Forms.TextBox
$txtPhone.Location = New-Object System.Drawing.Point(120, 177)
$txtPhone.Size = New-Object System.Drawing.Size(150, 25)
$pnlUserInfo.Controls.Add($txtPhone)

$lblManager = New-Object System.Windows.Forms.Label
$lblManager.Text = "Manager:"
$lblManager.Location = New-Object System.Drawing.Point(15, 210)
$lblManager.AutoSize = $true
$pnlUserInfo.Controls.Add($lblManager)

$script:cmbManager = New-Object System.Windows.Forms.ComboBox
$script:cmbManager.Location = New-Object System.Drawing.Point(120, 207)
$script:cmbManager.Size = New-Object System.Drawing.Size(200, 25)
$script:cmbManager.DropDownStyle = "DropDownList"
$pnlUserInfo.Controls.Add($script:cmbManager)

$lblPassword = New-Object System.Windows.Forms.Label
$lblPassword.Text = "Password:"
$lblPassword.Location = New-Object System.Drawing.Point(15, 240)
$lblPassword.AutoSize = $true
$pnlUserInfo.Controls.Add($lblPassword)

$txtNewPassword = New-Object System.Windows.Forms.TextBox
$txtNewPassword.Location = New-Object System.Drawing.Point(120, 237)
$txtNewPassword.Size = New-Object System.Drawing.Size(150, 25)
$pnlUserInfo.Controls.Add($txtNewPassword)

$btnGeneratePassword = New-Object System.Windows.Forms.Button
$btnGeneratePassword.Text = "Generate"
$btnGeneratePassword.Location = New-Object System.Drawing.Point(275, 236)
$btnGeneratePassword.Size = New-Object System.Drawing.Size(70, 25)
$pnlUserInfo.Controls.Add($btnGeneratePassword)

$tabCreate.Controls.Add($pnlUserInfo)

# Security Group Membership Panel
$pnlAppAccess = New-Object System.Windows.Forms.GroupBox
$pnlAppAccess.Text = "Security Group Membership"
$pnlAppAccess.Location = New-Object System.Drawing.Point(470, 10)
$pnlAppAccess.Size = New-Object System.Drawing.Size(480, 100)

$chkESlideAccess = New-Object System.Windows.Forms.CheckBox
$chkESlideAccess.Text = "Add user to $($Config.SecurityGroupName) group"
$chkESlideAccess.Location = New-Object System.Drawing.Point(20, 35)
$chkESlideAccess.Size = New-Object System.Drawing.Size(400, 25)
$chkESlideAccess.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$pnlAppAccess.Controls.Add($chkESlideAccess)

$tabCreate.Controls.Add($pnlAppAccess)

# Hide security group checkbox if no group configured
if (-not $Config.SecurityGroupDN) {
    $pnlAppAccess.Visible = $false
}

# Email Configuration Panel
$pnlEmail = New-Object System.Windows.Forms.GroupBox
$pnlEmail.Text = "Email Configuration"
$pnlEmail.Location = New-Object System.Drawing.Point(10, 300)
$pnlEmail.Size = New-Object System.Drawing.Size(450, 150)

$lblPrimaryEmail = New-Object System.Windows.Forms.Label
$lblPrimaryEmail.Text = "Primary Email (SMTP):"
$lblPrimaryEmail.Location = New-Object System.Drawing.Point(15, 30)
$lblPrimaryEmail.AutoSize = $true
$pnlEmail.Controls.Add($lblPrimaryEmail)

$txtPrimaryEmail = New-Object System.Windows.Forms.TextBox
$txtPrimaryEmail.Location = New-Object System.Drawing.Point(150, 27)
$txtPrimaryEmail.Size = New-Object System.Drawing.Size(280, 25)
$txtPrimaryEmail.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 200)
$pnlEmail.Controls.Add($txtPrimaryEmail)

$lblEmailNote = New-Object System.Windows.Forms.Label
$lblEmailNote.Text = "(Auto-generated from username, or enter custom)"
$lblEmailNote.ForeColor = [System.Drawing.Color]::Gray
$lblEmailNote.Location = New-Object System.Drawing.Point(150, 52)
$lblEmailNote.AutoSize = $true
$pnlEmail.Controls.Add($lblEmailNote)

$chkMustChangePassword = New-Object System.Windows.Forms.CheckBox
$chkMustChangePassword.Text = "User must change password at next logon"
$chkMustChangePassword.Location = New-Object System.Drawing.Point(15, 80)
$chkMustChangePassword.AutoSize = $true
$chkMustChangePassword.Checked = $true
$pnlEmail.Controls.Add($chkMustChangePassword)

$chkPasswordNeverExpires = New-Object System.Windows.Forms.CheckBox
$chkPasswordNeverExpires.Text = "Password never expires"
$chkPasswordNeverExpires.Location = New-Object System.Drawing.Point(15, 105)
$chkPasswordNeverExpires.AutoSize = $true
$pnlEmail.Controls.Add($chkPasswordNeverExpires)

$tabCreate.Controls.Add($pnlEmail)

# Create Button
$btnCreateUser = New-Object System.Windows.Forms.Button
$btnCreateUser.Text = "Create User"
$btnCreateUser.Location = New-Object System.Drawing.Point(10, 460)
$btnCreateUser.Size = New-Object System.Drawing.Size(150, 40)
$btnCreateUser.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
$btnCreateUser.ForeColor = [System.Drawing.Color]::White
$btnCreateUser.FlatStyle = "Flat"
$btnCreateUser.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$tabCreate.Controls.Add($btnCreateUser)

$btnClearForm = New-Object System.Windows.Forms.Button
$btnClearForm.Text = "Clear Form"
$btnClearForm.Location = New-Object System.Drawing.Point(170, 460)
$btnClearForm.Size = New-Object System.Drawing.Size(100, 40)
$btnClearForm.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnClearForm.ForeColor = [System.Drawing.Color]::White
$btnClearForm.FlatStyle = "Flat"
$tabCreate.Controls.Add($btnClearForm)

$tabControl.TabPages.Add($tabCreate)

# ============================================================================
# TAB 3: SECURITY GROUP MEMBERSHIP
# ============================================================================

$tabESlide = New-Object System.Windows.Forms.TabPage
$tabESlide.Text = "Security Group"
$tabESlide.BackColor = [System.Drawing.Color]::White

$lblSelectUserESlide = New-Object System.Windows.Forms.Label
$lblSelectUserESlide.Text = "Select User:"
$lblSelectUserESlide.Location = New-Object System.Drawing.Point(15, 20)
$lblSelectUserESlide.AutoSize = $true
$tabESlide.Controls.Add($lblSelectUserESlide)

$script:cmbESlideUser = New-Object System.Windows.Forms.ComboBox
$script:cmbESlideUser.Location = New-Object System.Drawing.Point(100, 17)
$script:cmbESlideUser.Size = New-Object System.Drawing.Size(300, 25)
$script:cmbESlideUser.DropDownStyle = "DropDownList"
$tabESlide.Controls.Add($script:cmbESlideUser)

$btnLoadESlide = New-Object System.Windows.Forms.Button
$btnLoadESlide.Text = "Load"
$btnLoadESlide.Location = New-Object System.Drawing.Point(410, 15)
$btnLoadESlide.Size = New-Object System.Drawing.Size(70, 28)
$btnLoadESlide.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$btnLoadESlide.ForeColor = [System.Drawing.Color]::White
$btnLoadESlide.FlatStyle = "Flat"
$tabESlide.Controls.Add($btnLoadESlide)

# Security Group Panel
$pnlESlide = New-Object System.Windows.Forms.GroupBox
$pnlESlide.Text = "$($Config.SecurityGroupName) Membership"
$pnlESlide.Location = New-Object System.Drawing.Point(15, 60)
$pnlESlide.Size = New-Object System.Drawing.Size(500, 150)

$lblESlideStatus = New-Object System.Windows.Forms.Label
$lblESlideStatus.Text = "Current Status: Not Loaded"
$lblESlideStatus.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$lblESlideStatus.Location = New-Object System.Drawing.Point(20, 35)
$lblESlideStatus.AutoSize = $true
$pnlESlide.Controls.Add($lblESlideStatus)

$btnGrantESlide = New-Object System.Windows.Forms.Button
$btnGrantESlide.Text = "Add to Group"
$btnGrantESlide.Location = New-Object System.Drawing.Point(20, 80)
$btnGrantESlide.Size = New-Object System.Drawing.Size(180, 40)
$btnGrantESlide.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
$btnGrantESlide.ForeColor = [System.Drawing.Color]::White
$btnGrantESlide.FlatStyle = "Flat"
$btnGrantESlide.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$pnlESlide.Controls.Add($btnGrantESlide)

$btnRevokeESlide = New-Object System.Windows.Forms.Button
$btnRevokeESlide.Text = "Remove from Group"
$btnRevokeESlide.Location = New-Object System.Drawing.Point(220, 80)
$btnRevokeESlide.Size = New-Object System.Drawing.Size(180, 40)
$btnRevokeESlide.BackColor = [System.Drawing.Color]::FromArgb(209, 52, 56)
$btnRevokeESlide.ForeColor = [System.Drawing.Color]::White
$btnRevokeESlide.FlatStyle = "Flat"
$btnRevokeESlide.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$pnlESlide.Controls.Add($btnRevokeESlide)

$tabESlide.Controls.Add($pnlESlide)

# Info
$lblESlideInfo = New-Object System.Windows.Forms.Label
$lblESlideInfo.Text = @"
Security Group Membership

Manage membership in the configured AD security group.
Group: $($Config.SecurityGroupDN)

1. Select a user from the dropdown
2. Click 'Load' to check their current membership
3. Use the buttons to add or remove the user
"@
$lblESlideInfo.Location = New-Object System.Drawing.Point(15, 220)
$lblESlideInfo.Size = New-Object System.Drawing.Size(600, 150)
$lblESlideInfo.ForeColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$tabESlide.Controls.Add($lblESlideInfo)

$tabControl.TabPages.Add($tabESlide)

# Hide Security Group tab if no group is configured
if (-not $Config.SecurityGroupDN) {
    $tabControl.TabPages.Remove($tabESlide)
}

$form.Controls.Add($tabControl)

# ============================================================================
# PROGRESS BAR
# ============================================================================

$script:progressBar = New-Object System.Windows.Forms.ProgressBar
$script:progressBar.Location = New-Object System.Drawing.Point(10, 565)
$script:progressBar.Size = New-Object System.Drawing.Size(850, 23)
$script:progressBar.Style = "Continuous"
$script:progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$script:progressBar.Minimum = 0
$script:progressBar.Maximum = 100
$script:progressBar.Value = 0
$form.Controls.Add($script:progressBar)

$script:lblProgress = New-Object System.Windows.Forms.Label
$script:lblProgress.Location = New-Object System.Drawing.Point(870, 567)
$script:lblProgress.Size = New-Object System.Drawing.Size(105, 20)
$script:lblProgress.Text = "Ready"
$script:lblProgress.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($script:lblProgress)

# ============================================================================
# LOG PANEL
# ============================================================================

$pnlLog = New-Object System.Windows.Forms.GroupBox
$pnlLog.Text = "Activity Log"
$pnlLog.Location = New-Object System.Drawing.Point(10, 593)
$pnlLog.Size = New-Object System.Drawing.Size(965, 112)
$pnlLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$script:txtLog = New-Object System.Windows.Forms.TextBox
$script:txtLog.Location = New-Object System.Drawing.Point(10, 20)
$script:txtLog.Size = New-Object System.Drawing.Size(945, 82)
$script:txtLog.Multiline = $true
$script:txtLog.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$script:txtLog.ReadOnly = $true
$script:txtLog.ScrollBars = "Vertical"
$script:txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$script:txtLog.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$script:txtLog.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
$pnlLog.Controls.Add($script:txtLog)

$form.Controls.Add($pnlLog)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

# Auto-generate username from first/last name
$txtFirstName.Add_TextChanged({
    Reset-InactivityTimer
    if ($txtFirstName.Text -and $txtLastName.Text) {
        $first = $txtFirstName.Text.ToLower() -replace '[^a-z]',''
        $last = $txtLastName.Text.ToLower() -replace '[^a-z]',''
        $username = "$first.$last"
        $txtUsername.Text = $username
        $txtPrimaryEmail.Text = "$username@$($Config.EmailDomain)"
    }
})

$txtLastName.Add_TextChanged({
    Reset-InactivityTimer
    if ($txtFirstName.Text -and $txtLastName.Text) {
        $first = $txtFirstName.Text.ToLower() -replace '[^a-z]',''
        $last = $txtLastName.Text.ToLower() -replace '[^a-z]',''
        $username = "$first.$last"
        $txtUsername.Text = $username
        $txtPrimaryEmail.Text = "$username@$($Config.EmailDomain)"
    }
})

# Generate password
$btnGeneratePassword.Add_Click({
    Reset-InactivityTimer
    $txtNewPassword.Text = Generate-SecurePassword
})

# Refresh user list
$btnRefresh.Add_Click({
    Reset-InactivityTimer
    Refresh-UserList
})

# Show disabled checkbox
$chkShowDisabled.Add_CheckedChanged({
    Reset-InactivityTimer
    Refresh-UserList
})

# User selection changed
$lstUsers.Add_SelectedIndexChanged({
    Reset-InactivityTimer
    if ($lstUsers.SelectedItems.Count -gt 0) {
        $user = $lstUsers.SelectedItems[0].Tag
        $details = @"
Username:    $($user.SamAccountName)
Display:     $($user.DisplayName)
Title:       $($user.Title)
Department:  $($user.Department)
Phone:       $($user.telephoneNumber)
Email:       $($user.mail)
Status:      $(if ($user.Enabled) { "Active" } else { "Disabled" })

Aliases:
$($user.proxyAddresses -join "`r`n")
"@
        $txtUserDetails.Text = $details
    }
})

# Edit User
$btnEditUser.Add_Click({
    Reset-InactivityTimer
    if ($script:lstUsers.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user first.", "Warning", "OK", "Warning")
        return
    }
    
    $user = $script:lstUsers.SelectedItems[0].Tag
    
    $editForm = New-Object System.Windows.Forms.Form
    $editForm.Text = "Edit User - $($user.SamAccountName)"
    $editForm.Size = New-Object System.Drawing.Size(500, 480)
    $editForm.StartPosition = "CenterParent"
    $editForm.FormBorderStyle = "FixedDialog"
    $editForm.MaximizeBox = $false
    $editForm.MinimizeBox = $false
    $editForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $yPos = 20
    
    $lblEditFirst = New-Object System.Windows.Forms.Label
    $lblEditFirst.Text = "First Name:"
    $lblEditFirst.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditFirst.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditFirst)
    
    $txtEditFirst = New-Object System.Windows.Forms.TextBox
    $txtEditFirst.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditFirst.Size = New-Object System.Drawing.Size(200, 23)
    $txtEditFirst.Text = $user.GivenName
    $editForm.Controls.Add($txtEditFirst)
    
    $yPos += 35
    
    $lblEditLast = New-Object System.Windows.Forms.Label
    $lblEditLast.Text = "Last Name:"
    $lblEditLast.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditLast.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditLast)
    
    $txtEditLast = New-Object System.Windows.Forms.TextBox
    $txtEditLast.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditLast.Size = New-Object System.Drawing.Size(200, 23)
    $txtEditLast.Text = $user.Surname
    $editForm.Controls.Add($txtEditLast)
    
    $yPos += 35
    
    $lblEditDisplay = New-Object System.Windows.Forms.Label
    $lblEditDisplay.Text = "Display Name:"
    $lblEditDisplay.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditDisplay.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditDisplay)
    
    $txtEditDisplay = New-Object System.Windows.Forms.TextBox
    $txtEditDisplay.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditDisplay.Size = New-Object System.Drawing.Size(300, 23)
    $txtEditDisplay.Text = $user.DisplayName
    $editForm.Controls.Add($txtEditDisplay)
    
    $yPos += 35
    
    $lblEditEmail = New-Object System.Windows.Forms.Label
    $lblEditEmail.Text = "Email / UPN:"
    $lblEditEmail.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditEmail.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditEmail)
    
    $emailUser = if ($user.mail) { ($user.mail -split "@")[0] } else { $user.SamAccountName }
    
    $txtEditEmail = New-Object System.Windows.Forms.TextBox
    $txtEditEmail.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditEmail.Size = New-Object System.Drawing.Size(150, 23)
    $txtEditEmail.Text = $emailUser
    $editForm.Controls.Add($txtEditEmail)
    
    $lblEmailDomain = New-Object System.Windows.Forms.Label
    $lblEmailDomain.Text = "@$($Config.EmailDomain)"
    $lblEmailDomain.Location = New-Object System.Drawing.Point(285, ($yPos + 3))
    $lblEmailDomain.Size = New-Object System.Drawing.Size(150, 23)
    $lblEmailDomain.ForeColor = [System.Drawing.Color]::Gray
    $editForm.Controls.Add($lblEmailDomain)
    
    $yPos += 22
    
    $lblEmailWarning = New-Object System.Windows.Forms.Label
    $lblEmailWarning.Text = "Warning: Changing email will update UPN and affect user sign-in!"
    $lblEmailWarning.ForeColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
    $lblEmailWarning.Location = New-Object System.Drawing.Point(130, $yPos)
    $lblEmailWarning.Size = New-Object System.Drawing.Size(350, 20)
    $lblEmailWarning.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $editForm.Controls.Add($lblEmailWarning)
    
    $yPos += 30
    
    $lblEditTitle = New-Object System.Windows.Forms.Label
    $lblEditTitle.Text = "Title:"
    $lblEditTitle.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditTitle.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditTitle)
    
    $txtEditTitle = New-Object System.Windows.Forms.TextBox
    $txtEditTitle.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditTitle.Size = New-Object System.Drawing.Size(300, 23)
    $txtEditTitle.Text = $user.Title
    $editForm.Controls.Add($txtEditTitle)
    
    $yPos += 35
    
    $lblEditDept = New-Object System.Windows.Forms.Label
    $lblEditDept.Text = "Department:"
    $lblEditDept.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditDept.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditDept)
    
    $txtEditDept = New-Object System.Windows.Forms.TextBox
    $txtEditDept.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditDept.Size = New-Object System.Drawing.Size(300, 23)
    $txtEditDept.Text = $user.Department
    $editForm.Controls.Add($txtEditDept)
    
    $yPos += 35
    
    $lblEditPhone = New-Object System.Windows.Forms.Label
    $lblEditPhone.Text = "Phone:"
    $lblEditPhone.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditPhone.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditPhone)
    
    $txtEditPhone = New-Object System.Windows.Forms.TextBox
    $txtEditPhone.Location = New-Object System.Drawing.Point(130, $yPos)
    $txtEditPhone.Size = New-Object System.Drawing.Size(200, 23)
    $txtEditPhone.Text = $user.telephoneNumber
    $editForm.Controls.Add($txtEditPhone)
    
    $yPos += 35
    
    $lblEditManager = New-Object System.Windows.Forms.Label
    $lblEditManager.Text = "Manager:"
    $lblEditManager.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblEditManager.Size = New-Object System.Drawing.Size(100, 23)
    $editForm.Controls.Add($lblEditManager)
    
    $cmbEditManager = New-Object System.Windows.Forms.ComboBox
    $cmbEditManager.Location = New-Object System.Drawing.Point(130, $yPos)
    $cmbEditManager.Size = New-Object System.Drawing.Size(300, 23)
    $cmbEditManager.DropDownStyle = "DropDownList"
    $cmbEditManager.Items.Add("")
    
    foreach ($item in $script:cmbManager.Items) {
        if ($item -ne "") {
            $cmbEditManager.Items.Add($item)
        }
    }
    $editForm.Controls.Add($cmbEditManager)
    
    $yPos += 50
    
    $btnSaveEdit = New-Object System.Windows.Forms.Button
    $btnSaveEdit.Text = "Save Changes"
    $btnSaveEdit.Location = New-Object System.Drawing.Point(130, $yPos)
    $btnSaveEdit.Size = New-Object System.Drawing.Size(120, 35)
    $btnSaveEdit.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
    $btnSaveEdit.ForeColor = [System.Drawing.Color]::White
    $btnSaveEdit.FlatStyle = "Flat"
    $editForm.Controls.Add($btnSaveEdit)
    
    $btnCancelEdit = New-Object System.Windows.Forms.Button
    $btnCancelEdit.Text = "Cancel"
    $btnCancelEdit.Location = New-Object System.Drawing.Point(260, $yPos)
    $btnCancelEdit.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancelEdit.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $btnCancelEdit.ForeColor = [System.Drawing.Color]::White
    $btnCancelEdit.FlatStyle = "Flat"
    $editForm.Controls.Add($btnCancelEdit)
    
    $btnCancelEdit.Add_Click({ $editForm.Close() })
    
    $btnSaveEdit.Add_Click({
        $sam = $user.SamAccountName
        $newFirst = $txtEditFirst.Text.Trim()
        $newLast = $txtEditLast.Text.Trim()
        $newDisplay = $txtEditDisplay.Text.Trim()
        $newEmail = "$($txtEditEmail.Text.Trim())@$($Config.EmailDomain)"
        $newTitle = $txtEditTitle.Text.Trim()
        $newDept = $txtEditDept.Text.Trim()
        $newPhone = $txtEditPhone.Text.Trim()
        $originalEmail = $user.mail
        
        $newManagerDN = $null
        if ($cmbEditManager.SelectedItem -and $cmbEditManager.SelectedItem -ne "") {
            $newManagerDN = ($cmbEditManager.SelectedItem -split " - ")[1]
        }
        
        if ($newEmail -ne $originalEmail -and $originalEmail) {
            $confirmEmail = [System.Windows.Forms.MessageBox]::Show(
                "You are changing the email/UPN from:`n$originalEmail`n`nTo:`n$newEmail`n`nThis WILL affect the user's sign-in account!`n`nAre you sure?",
                "Confirm Email/UPN Change", "YesNo", "Warning"
            )
            if ($confirmEmail -ne "Yes") { return }
        }
        
        try {
            Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
                param($sam, $newFirst, $newLast, $newDisplay, $newEmail, $newTitle, $newDept, $newPhone, $newManagerDN, $originalEmail)
                
                Import-Module ActiveDirectory
                
                $params = @{
                    Identity = $sam
                    GivenName = $newFirst
                    Surname = $newLast
                    DisplayName = $newDisplay
                }
                
                if ($newTitle) { $params.Title = $newTitle } else { $params.Clear = @("Title") }
                if ($newDept) { $params.Department = $newDept }
                if ($newPhone) { $params.OfficePhone = $newPhone }
                
                Set-ADUser @params
                
                if ($newManagerDN) {
                    Set-ADUser -Identity $sam -Manager $newManagerDN
                } else {
                    Set-ADUser -Identity $sam -Clear Manager
                }
                
                if ($newEmail -and $newEmail -ne $originalEmail) {
                    Set-ADUser -Identity $sam -UserPrincipalName $newEmail
                    Set-ADUser -Identity $sam -EmailAddress $newEmail
                    
                    $adUser = Get-ADUser -Identity $sam -Properties proxyAddresses
                    $currentProxies = @($adUser.proxyAddresses)
                    $updatedProxies = @()
                    
                    foreach ($proxy in $currentProxies) {
                        if ($proxy -clike "SMTP:*") {
                            $updatedProxies += $proxy -replace "^SMTP:", "smtp:"
                        } else {
                            $updatedProxies += $proxy
                        }
                    }
                    
                    $updatedProxies += "SMTP:$newEmail"
                    
                    Set-ADUser -Identity $sam -Clear proxyAddresses
                    Set-ADUser -Identity $sam -Add @{proxyAddresses = $updatedProxies}
                }
                
            } -ArgumentList $sam, $newFirst, $newLast, $newDisplay, $newEmail, $newTitle, $newDept, $newPhone, $newManagerDN, $originalEmail
            
            Write-Log "Updated user: $sam"
            if ($newEmail -ne $originalEmail -and $originalEmail) {
                Write-Log "Changed email/UPN for $sam from $originalEmail to $newEmail"
            }
            
            [System.Windows.Forms.MessageBox]::Show("User updated successfully.", "Success", "OK", "Information")
            $editForm.Close()
            Refresh-UserList
        }
        catch {
            Write-Log "Error updating user: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error updating user: $_", "Error", "OK", "Error")
        }
    })
    
    [void]$editForm.ShowDialog()
})

# Create User
$btnCreateUser.Add_Click({
    Reset-InactivityTimer
    if (-not $txtFirstName.Text -or -not $txtLastName.Text) {
        [System.Windows.Forms.MessageBox]::Show("First Name and Last Name are required.", "Validation Error", "OK", "Warning")
        return
    }
    
    if (-not $txtNewPassword.Text) {
        [System.Windows.Forms.MessageBox]::Show("Password is required.", "Validation Error", "OK", "Warning")
        return
    }
    
    Set-Progress -Percent 20 -Status "Creating user..."
    
    try {
        $username = $txtUsername.Text
        $displayName = "$($txtFirstName.Text) $($txtLastName.Text)"
        $email = $txtPrimaryEmail.Text
        $upn = "$username@$($Config.EmailDomain)"
        $firstName = $txtFirstName.Text
        $lastName = $txtLastName.Text
        $title = $txtTitle.Text
        $department = $txtDepartment.Text
        $phone = $txtPhone.Text
        $password = $txtNewPassword.Text
        $mustChange = $chkMustChangePassword.Checked
        $neverExpires = $chkPasswordNeverExpires.Checked
        $standardOU = $Config.StandardUsersOU
        $secGroupDN = $Config.SecurityGroupDN
        $addToGroup = $chkESlideAccess.Checked
        
        $managerDN = $null
        if ($script:cmbManager.SelectedItem -and $script:cmbManager.SelectedItem -ne "") {
            $managerDN = ($script:cmbManager.SelectedItem -split " - ")[1]
        }
        
        Set-Progress -Percent 50 -Status "Creating in AD..."
        
        $result = Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
            param($username, $displayName, $email, $upn, $firstName, $lastName, $title, $department, $phone, $password, $mustChange, $neverExpires, $standardOU, $secGroupDN, $addToGroup, $managerDN)
            
            Import-Module ActiveDirectory
            
            $existingUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
            if ($existingUser) {
                return @{ Success = $false; Error = "Username '$username' already exists." }
            }
            
            $userParams = @{
                Name              = $displayName
                GivenName         = $firstName
                Surname           = $lastName
                SamAccountName    = $username
                UserPrincipalName = $upn
                DisplayName       = $displayName
                Path              = $standardOU
                AccountPassword   = (ConvertTo-SecureString $password -AsPlainText -Force)
                Enabled           = $true
                ChangePasswordAtLogon = $mustChange
                PasswordNeverExpires  = $neverExpires
            }
            
            if ($title) { $userParams.Title = $title }
            if ($department) { $userParams.Department = $department }
            if ($phone) { $userParams.OfficePhone = $phone }
            
            New-ADUser @userParams
            
            if ($managerDN) {
                Set-ADUser -Identity $username -Manager $managerDN
            }
            
            $proxyAddresses = @("SMTP:$email")
            Set-ADUser -Identity $username -EmailAddress $email -Add @{proxyAddresses = $proxyAddresses}
            
            if ($addToGroup -and $secGroupDN) {
                Add-ADGroupMember -Identity $secGroupDN -Members $username
            }
            
            return @{ Success = $true }
            
        } -ArgumentList $username, $displayName, $email, $upn, $firstName, $lastName, $title, $department, $phone, $password, $mustChange, $neverExpires, $standardOU, $secGroupDN, $addToGroup, $managerDN
        
        Set-Progress -Percent 90 -Status "Finishing..."
        
        if ($result.Success) {
            Write-Log "Created user: $username ($displayName)"
            if ($addToGroup) { Write-Log "Added $username to $($Config.SecurityGroupName) group" }
            
            [System.Windows.Forms.MessageBox]::Show(
                "User '$displayName' created successfully!`n`nUsername: $username`nEmail: $email`nPassword: $password",
                "Success", "OK", "Information"
            )
            
            $btnClearForm.PerformClick()
            Refresh-UserList
        }
        else {
            [System.Windows.Forms.MessageBox]::Show($result.Error, "Error", "OK", "Error")
        }
    }
    catch {
        Write-Log "Error creating user: $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error creating user: $_", "Error", "OK", "Error")
    }
    
    Reset-Progress
})

# Clear form
$btnClearForm.Add_Click({
    Reset-InactivityTimer
    $txtFirstName.Text = ""
    $txtLastName.Text = ""
    $txtUsername.Text = ""
    $txtTitle.Text = ""
    $txtDepartment.Text = ""
    $txtPhone.Text = ""
    $txtNewPassword.Text = ""
    $txtPrimaryEmail.Text = ""
    $script:cmbManager.SelectedIndex = -1
    $chkESlideAccess.Checked = $false
})

# Reset Password
$btnResetPassword.Add_Click({
    Reset-InactivityTimer
    if ($lstUsers.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user first.", "Warning", "OK", "Warning")
        return
    }
    
    $user = $lstUsers.SelectedItems[0].Tag
    $newPassword = Generate-SecurePassword
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Reset password for $($user.DisplayName)?`n`nNew password will be: $newPassword",
        "Confirm Password Reset", "YesNo", "Question"
    )
    
    if ($result -eq "Yes") {
        Set-Progress -Percent 50 -Status "Resetting..."
        try {
            $sam = $user.SamAccountName
            Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
                param($sam, $newPassword)
                Import-Module ActiveDirectory
                Set-ADAccountPassword -Identity $sam -Reset -NewPassword (ConvertTo-SecureString $newPassword -AsPlainText -Force)
                Set-ADUser -Identity $sam -ChangePasswordAtLogon $true
            } -ArgumentList $sam, $newPassword
            
            Write-Log "Password reset for $sam"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Password reset successful!`n`nNew Password: $newPassword`n`nUser must change password at next login.",
                "Success", "OK", "Information"
            )
        }
        catch {
            Write-Log "Error resetting password: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error resetting password: $_", "Error", "OK", "Error")
        }
        Reset-Progress
    }
})

# Disable User
$btnDisableUser.Add_Click({
    Reset-InactivityTimer
    if ($lstUsers.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user first.", "Warning", "OK", "Warning")
        return
    }
    
    $user = $lstUsers.SelectedItems[0].Tag
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Disable user '$($user.DisplayName)'?`n`nThe account will be disabled and moved to the Disabled Accounts OU.",
        "Confirm Disable User", "YesNo", "Warning"
    )
    
    if ($result -eq "Yes") {
        Set-Progress -Percent 50 -Status "Disabling..."
        try {
            $sam = $user.SamAccountName
            $dn = $user.DistinguishedName
            $disabledOU = $Config.DisabledUsersOU
            
            Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
                param($sam, $dn, $disabledOU)
                Import-Module ActiveDirectory
                Disable-ADAccount -Identity $sam
                Move-ADObject -Identity $dn -TargetPath $disabledOU
            } -ArgumentList $sam, $dn, $disabledOU
            
            Write-Log "Disabled account: $sam"
            Write-Log "Moved $sam to Disabled Accounts OU"
            
            [System.Windows.Forms.MessageBox]::Show("User disabled and moved successfully.", "Success", "OK", "Information")
            Refresh-UserList
        }
        catch {
            Write-Log "Error disabling user: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error disabling user: $_", "Error", "OK", "Error")
        }
        Reset-Progress
    }
})

# Enable User
$btnEnableUser.Add_Click({
    Reset-InactivityTimer
    if ($lstUsers.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user first.", "Warning", "OK", "Warning")
        return
    }
    
    $user = $lstUsers.SelectedItems[0].Tag
    
    if ($user.Enabled) {
        [System.Windows.Forms.MessageBox]::Show("User is already enabled.", "Info", "OK", "Information")
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Enable user '$($user.DisplayName)'?`n`nThe account will be enabled and moved back to the Standard Users OU.",
        "Confirm Enable User", "YesNo", "Question"
    )
    
    if ($result -eq "Yes") {
        Set-Progress -Percent 50 -Status "Enabling..."
        try {
            $sam = $user.SamAccountName
            $dn = $user.DistinguishedName
            $standardOU = $Config.StandardUsersOU
            
            Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
                param($sam, $dn, $standardOU)
                Import-Module ActiveDirectory
                Enable-ADAccount -Identity $sam
                Move-ADObject -Identity $dn -TargetPath $standardOU
            } -ArgumentList $sam, $dn, $standardOU
            
            Write-Log "Enabled account: $sam"
            Write-Log "Moved $sam to Standard Users OU"
            
            [System.Windows.Forms.MessageBox]::Show("User enabled and moved successfully.", "Success", "OK", "Information")
            Refresh-UserList
        }
        catch {
            Write-Log "Error enabling user: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error enabling user: $_", "Error", "OK", "Error")
        }
        Reset-Progress
    }
})

# ============================================================================
# SECURITY GROUP EVENT HANDLERS
# ============================================================================

# Load Membership Status
$btnLoadESlide.Add_Click({
    Reset-InactivityTimer
    if ($script:cmbESlideUser.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user.", "Warning", "OK", "Warning")
        return
    }
    
    $username = ($script:cmbESlideUser.SelectedItem -split " - ")[0]
    $secGroupDN = $Config.SecurityGroupDN
    
    Set-Progress -Percent 50 -Status "Loading..."
    
    try {
        $isMember = Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
            param($username, $secGroupDN)
            Import-Module ActiveDirectory
            $members = Get-ADGroupMember -Identity $secGroupDN -ErrorAction SilentlyContinue
            return ($members | Where-Object { $_.SamAccountName -eq $username }) -ne $null
        } -ArgumentList $username, $secGroupDN
        
        if ($isMember) {
            $lblESlideStatus.Text = "Current Status: MEMBER"
            $lblESlideStatus.ForeColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
        }
        else {
            $lblESlideStatus.Text = "Current Status: NOT A MEMBER"
            $lblESlideStatus.ForeColor = [System.Drawing.Color]::FromArgb(209, 52, 56)
        }
        Write-Log "Loaded group membership status for $username"
    }
    catch {
        Write-Log "Error checking group membership: $_" "ERROR"
        $lblESlideStatus.Text = "Current Status: Error loading"
        $lblESlideStatus.ForeColor = [System.Drawing.Color]::Gray
    }
    Reset-Progress
})

# Add to Group
$btnGrantESlide.Add_Click({
    Reset-InactivityTimer
    if ($script:cmbESlideUser.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user and click Load first.", "Warning", "OK", "Warning")
        return
    }
    
    $username = ($script:cmbESlideUser.SelectedItem -split " - ")[0]
    $secGroupDN = $Config.SecurityGroupDN
    
    Set-Progress -Percent 50 -Status "Adding..."
    
    try {
        Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
            param($username, $secGroupDN)
            Import-Module ActiveDirectory
            Add-ADGroupMember -Identity $secGroupDN -Members $username
        } -ArgumentList $username, $secGroupDN
        
        Write-Log "Added $username to $($Config.SecurityGroupName) group"
        $btnLoadESlide.PerformClick()
        [System.Windows.Forms.MessageBox]::Show("User added to $($Config.SecurityGroupName) group.", "Success", "OK", "Information")
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            [System.Windows.Forms.MessageBox]::Show("User is already a member of this group.", "Info", "OK", "Information")
        }
        else {
            Write-Log "Error updating group membership: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error adding to group: $_", "Error", "OK", "Error")
        }
    }
    Reset-Progress
})

# Remove from Group
$btnRevokeESlide.Add_Click({
    Reset-InactivityTimer
    if ($script:cmbESlideUser.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please select a user and click Load first.", "Warning", "OK", "Warning")
        return
    }
    
    $username = ($script:cmbESlideUser.SelectedItem -split " - ")[0]
    $secGroupDN = $Config.SecurityGroupDN
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Remove this user from the $($Config.SecurityGroupName) group?",
        "Confirm Remove", "YesNo", "Question"
    )
    
    if ($result -eq "Yes") {
        Set-Progress -Percent 50 -Status "Removing..."
        try {
            Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
                param($username, $secGroupDN)
                Import-Module ActiveDirectory
                Remove-ADGroupMember -Identity $secGroupDN -Members $username -Confirm:$false
            } -ArgumentList $username, $secGroupDN
            
            Write-Log "Removed $username from $($Config.SecurityGroupName) group"
            $btnLoadESlide.PerformClick()
            [System.Windows.Forms.MessageBox]::Show("User removed from $($Config.SecurityGroupName) group.", "Success", "OK", "Information")
        }
        catch {
            Write-Log "Error updating group membership: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show("Error removing from group: $_", "Error", "OK", "Error")
        }
        Reset-Progress
    }
})

# ============================================================================
# FORM LOAD
# ============================================================================

$form.Add_Shown({
    $script:inactivityTimer.Start()
    
    Write-Log "AD User Management Tool v1.0 started"
    Write-Log "Authenticated user: $($script:AuthenticatedUser)"
    Write-Log "Domain Controller: $($Config.DomainController)"
    Write-Log "Session timeout: $($Config.SessionTimeoutMinutes) minutes"
    
    try {
        Write-Log "Testing connection to domain controller..."
        Set-Progress -Percent 20 -Status "Connecting to DC..."
        
        $testConnection = Invoke-Command -ComputerName $Config.DomainController -ScriptBlock { 
            Import-Module ActiveDirectory
            return $true 
        } -ErrorAction Stop
        Write-Log "Connected to $($Config.DomainController)"
        
        Set-Progress -Percent 40 -Status "Loading managers..."
        
        $managers = Invoke-Command -ComputerName $Config.DomainController -ScriptBlock {
            param($standardOU)
            Import-Module ActiveDirectory
            Get-ADUser -Filter "Enabled -eq `$true" -SearchBase $standardOU -Properties DisplayName |
                Select-Object SamAccountName, DisplayName, DistinguishedName |
                Sort-Object DisplayName
        } -ArgumentList $Config.StandardUsersOU
        
        $script:cmbManager.Items.Add("")
        foreach ($mgr in $managers) {
            $script:cmbManager.Items.Add("$($mgr.SamAccountName) - $($mgr.DistinguishedName)")
        }
        
        foreach ($mgr in $managers) {
            if ($Config.SecurityGroupDN) {
                $script:cmbESlideUser.Items.Add("$($mgr.SamAccountName) - $($mgr.DisplayName)")
            }
        }
        
        Set-Progress -Percent 60 -Status "Loading users..."
        Refresh-UserList
        
        Write-Log "Initialization complete"
    }
    catch {
        Write-Log "Error during initialization: $_" "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "Error connecting to Domain Controller.`n`nMake sure:`n- You have network access to $($Config.DomainController)`n- PowerShell Remoting is enabled on the DC`n- You have permissions to connect`n`nError: $_",
            "Initialization Error", "OK", "Error"
        )
    }
    
    Reset-Progress
})

$form.Add_FormClosing({
    if ($script:inactivityTimer) {
        $script:inactivityTimer.Stop()
        $script:inactivityTimer.Dispose()
    }
})

# ============================================================================
# RUN APPLICATION
# ============================================================================

[void]$form.ShowDialog()
