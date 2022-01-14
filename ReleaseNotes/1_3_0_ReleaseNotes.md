# Passbolt 1.3.0 release notes

## Added
- View presenting application logs allowing to share it easily
- Help menu in multiple contexts allowing access to logs and quick link to help page
- Quick account switch menu
- Account details view allowing change local label for accounts

## Improved
- Added long loading messages appearing on loaders that take more time than expected
- Implemented session refresh based on refresh tokens

## Fixed
- Delay on scanning QR codes
- Invalid resolve of urls on instances available under urls with additional path component
- Local JWT token verification issues 

## Security
- Removed custom application url scheme
- Added jailbreak detection

## Maintenance
- Refactor displayable strings for easier usage
- Refactor session management
