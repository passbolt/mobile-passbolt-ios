# Passbolt 3.3.0 release notes

## Added
- MOB-5185 Passkeys MFA support

## Security
- MOB-5125 Stop trusting server declared fingerprints for metadata keys
- MOB-5126 Stop trusting server declared fingerprints for user keys
- MOB-5127 Use random key for encrypting database
- MOB-5128 Use monotonic time for cache TTL calculation
- MOB-5129 Strip tokens from networking logs

## Maintenance
- MOB-5135 Bump app version and GopenPGP framework version
- MOB-5160 Drop iOS 16 support
- MOB-5167 Xcode 27 support
