# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-09-18

### Fixed
- **Configuration wizard was unusable** - the form was too short, leaving the Session Timeout field and the Save/Cancel buttons off the bottom edge. Field hints for the wide DN fields also ran past the right edge. Layout now fits; Enter saves and Esc cancels.
- Generated passwords could miss a character class (about 1 in 25) and be rejected by AD's complexity policy. Each password now contains at least one lowercase, uppercase, digit, and symbol.
- Closing the login window printed a red "Login cancelled" error to the console instead of exiting quietly.
- The Search box on the User Management tab did nothing. It now filters the list as you type across username, display name, title, and email, without re-querying AD.

### Changed
- **Login credentials are now used for AD operations.** Previously the login screen only verified the password and every remoting call ran as the Windows user who launched the tool. All `Invoke-Command` calls now pass the signed-in credential, so technicians can run the tool from a standard desktop session and sign in with a delegated admin account. Re-authentication after a timeout replaces the stored credential.
- Password generation uses `System.Security.Cryptography.RandomNumberGenerator` instead of `Get-Random`.
- Create User and Reset Password success dialogs offer to copy the password to the clipboard (opt-in, never automatic).
- Version is defined once (`$script:Version`) and shown consistently in the title bar and log.
- Main script has comment-based help (`Get-Help .\AD-UserManagement.ps1`).
- Wizard no longer claims to need elevation; it only writes `config.json` next to itself.
- Internal control names no longer reference a pre-release product name.

### Documentation
- README has a screen-by-screen walkthrough of the wizard, sign-in, and each tab.
- README and SETUP.md describe the credential model accurately, and note the execution-policy bypass needed on machines with the default `Restricted` policy.
- SETUP.md troubleshooting covers WinRM rejecting credentials that passed the domain check.

## [1.0.0] - 2026-03-24

### Added
- **Configuration Wizard** (`Configure-ADUserMgmt.ps1`) generates `config.json` for environment-specific values
- **User Management tab** - list, view details, edit attributes, reset password, disable/enable accounts
- **Create New User tab** - full user creation with auto-generated username/email, manager assignment, password options
- **Security Group tab** - check, add, and remove membership in a configurable AD security group (tab hidden when unconfigured)
- **Domain authentication** at login with configurable inactivity timeout and re-authentication
- **Activity log** panel with timestamped entries for all operations
- **Progress bar** for long-running AD queries
- Edit User dialog with email/UPN change support and proxyAddresses management

### Security
- All AD operations performed via PowerShell Remoting to the Domain Controller
- No credentials or secrets stored in config files
- `config.json` excluded from version control via `.gitignore`
- Optional launch restriction snippet provided in SETUP.md to limit access by group membership

### Notes
- This is the first public release. Prior versions were internal builds with environment-specific configuration.
