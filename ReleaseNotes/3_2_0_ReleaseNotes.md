# Passbolt 3.2.0 release notes

## Added
- MOB-4281 Show warning about deprecated OS version
- MOB-4589 Data refresh progress bar
- MOB-4731 Permission confirmation on share flow

## Improved
- MOB-4594 Show loading indicator when fetching password policies
- MOB-4729 Regenerate password when closing advanced password generator
- MOB-4896 Handle unsupported MFA methods gracefully
- MOB-4911 Paginate folders fetch during session data refresh
- MOB-4562 Session data refresh benchmarks
- MOB-4564 Concurrent processing during session data refresh
- MOB-4566 Multi-row inserts
- MOB-4567 Users, groups and folders upsert
- MOB-4694 Prepared statements in resources storage
- MOB-4698 Refactor resource tags storage

## Fixed
- MOB-4856 Use correct configuration for calculating password entropy

## Maintenance
- MOB-4542 Fix corrupted GopenPGP xcframework
- MOB-981 E2E tests for account menu and account management
- MOB-997 E2E tests for adding favorite resource
- MOB-1013 Use SQLCipher package
- MOB-4444 Snapshot tests infrastructure
- MOB-4730 Update GitHub issues config
- MOB-4757 Update readme and add security policy
- MOB-4900 UICommons snapshot tests
- MOB-5034 Screen snapshot tests
