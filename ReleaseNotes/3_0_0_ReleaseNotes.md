# Passbolt 3.0.0 release notes

## Added
- MOB-4121 Support for Pin Code resource type
- MOB-4157 Support for MFA on Autofill extension
- MOB-3956 Case insensitive search for resources, folders and tags

## Improved
- MOB-3950 Extend time required for subsequent authorization
- MOB-4053 Remove redundant authorization requests
- MOB-4118 Improve rendering of obfuscated font for encrypted note
- MOB-4154 Unify empty results display
- MOB-4240 Align expired resources display on TOTP tab
- MOB-4253 Resize TOTP context menu button

## Fixed
- MOB-1879 Fix fetching resource details (drop "personal" field in folders API)
- MOB-3992 Don't attempt to display username on resources without username
- MOB-4246 Handle permission duplication
- MOB-4256, MOB-4263 Fix drawers on iOS 16
- MOB-4269 Fix rendering same item in multiple sections in Autofill extension

## Maintenance
- MOB-4021 Swift 6 support for all targets
