# Passbolt 1.15.0 release notes

## Added
- Attaching OTP to an existing resource
- Editing standalone and attached OTP
- OTP display in resource details and on the OTP list

## Improved
- Refined logging which should gather more informations
- Data validation and invalid data handling

## Security
- Improved data validation
- Improved invalid data filtering and handling

## Fixed
- Missing english localization strings
- Network response decoding failure on iOS 17
- OTP secret Base32 decoding issues in handling invalid data

## Maintenance
- Rewrittern from scratch resource details, menu and editing screens
