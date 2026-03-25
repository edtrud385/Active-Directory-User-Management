# Changelog

All notable changes to this project will be documented in this file.

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
