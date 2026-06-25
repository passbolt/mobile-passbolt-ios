# Passbolt 3.1.0 release notes

## Added
- MOB-4220 Allow upgrading V4 resources to V5
- MOB-4225 Advanced password generation
- MOB-4483 Verify metadata signature validity

## Improved
- MOB-4085 Skip session data refresh when creating or editing resources
- MOB-4097 Remove redundant configuration fetch on sign-in
- MOB-4180 Update account transfer and Autofill setup instructions
- MOB-4215 Show refresh spinner on initial session data refresh
- MOB-4243 Update message when YubiKey scanning is not available

## Fixed
- MOB-4539 Fix metadata private key signature matching to use primary fingerprint
- MOB-4553 Synthesize user's own permission after creating a new resource

## Maintenance
- MOB-4466 Remove outdated tests
- MOB-3712 Refactor UI tests suite
