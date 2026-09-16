//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import Accounts
import FeatureScopes
import OSFeatures
import Session

// MARK: - Implementation

extension AccountPreferences {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let account: Account = try features.sessionAccount()
    let accountData: AccountData = try features.instance()
    let accountProfileStorage: AccountProfileStorage = try features.instance()
    let accountPassphraseStorage: AccountPassphraseStorage = try features.instance()
    let sessionPassphrase: SessionPassphrase = try features.instance()

    @Sendable nonisolated func setLocalAccountLabel(
      _ label: String
    ) throws {
      var profile: AccountProfile =
        try accountProfileStorage
        .loadAccountProfile(account.localID)
      profile.label = label
      try accountProfileStorage
        .updateAccountProfile(profile)
      accountData.updates.update()
    }

    @Sendable nonisolated func isPassphraseStored() -> Bool {
      accountPassphraseStorage.isAccountPassphraseStored(account.localID)
    }

    @Sendable nonisolated func storePassphrase(
      _ store: Bool
    ) async throws {
      try await sessionPassphrase.storeWithBiometry(store)
      accountData.updates.update()
    }

    let useLastHomePresentationAsDefaultProperty: UseLastUsedHomePresentationAsDefaultStoredProperty =
      try features.instance()
    let useLastHomePresentationAsDefault: StoredVariable<Bool> = useLastHomePresentationAsDefaultProperty
      .variable
      .convert(
        read: unwrapped(default: true),
        write: { $0 }
      )

    let defaultHomePresentationProperty: DefaultHomeModeStoredProperty =
      try features.instance()
    let defaultHomePresentation: StoredVariable<HomePresentationMode> = defaultHomePresentationProperty
      .variable
      .convert(
        read: unwrappedMap(
          default: .plainResourcesList,
          mapping: {
            HomePresentationMode
              .init(rawValue: $0)
          }
        ),
        write: { $0.rawValue }
      )

    let passphraseWipeOnBackgroundProperty: PassphraseWipeOnBackgroundKeychainProperty = try features.instance()
    let legacyPassphraseWipeOnBackgroundProperty: PassphraseWipeOnBackgroundStoredProperty = try features.instance()
    // The migration has to run before `passphraseWipeOnBackgroundProperty.variable` is accessed
    // for the first time below - that first access is what reads the keychain, and the result is
    // cached for the whole lifetime of the variable, so a value written afterwards would stay
    // invisible until the feature is reloaded.
    //
    // Both keychain calls are synchronous and this function runs on the main actor. It is a
    // one time, two item migration performed only for accounts which still hold the legacy value,
    // so the cost is bounded and paid at most once per account.
    if let legacyValue: Bool = legacyPassphraseWipeOnBackgroundProperty.variable.value {
      do {
        // `read` and `write` are used instead of the cached `variable` on purpose - the cache
        // reports an unreachable keychain as a missing value, and clearing the legacy value
        // after a migration that did not land would silently reset the setting to its default.
        if case .none = try passphraseWipeOnBackgroundProperty.read() {
          try passphraseWipeOnBackgroundProperty.write(legacyValue)
        }  // else - value was already migrated, keychain wins
        legacyPassphraseWipeOnBackgroundProperty.variable.assign(.none)
      }
      catch {
        // keep the legacy value, migration is retried on the next load
        error.logged(
          info: .message("Failed to migrate passphrase wipe setting to the keychain")
        )
      }
    }  // else - nothing to migrate

    let passphraseWipeOnBackground: StoredVariable<Bool> = passphraseWipeOnBackgroundProperty
      .variable
      .convert(
        read: unwrapped(default: false),
        write: { $0 }
      )
      .notifying(accountData.updates)

    @Sendable nonisolated func readPassphraseWipeOnBackground() throws -> Bool {
      try passphraseWipeOnBackgroundProperty.read() ?? false
    }

    return Self(
      updates: accountData.updates.asAnyUpdatable(),
      setLocalAccountLabel: setLocalAccountLabel(_:),
      isPassphraseStored: isPassphraseStored,
      storePassphrase: storePassphrase(_:),
      useLastHomePresentationAsDefault: useLastHomePresentationAsDefault,
      defaultHomePresentation: defaultHomePresentation,
      passphraseWipeOnBackground: passphraseWipeOnBackground,
      readPassphraseWipeOnBackground: readPassphraseWipeOnBackground
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountPreferences() {
    self.use(
      .lazyLoaded(
        AccountPreferences.self,
        load: AccountPreferences.load(features:)
      ),
      in: SessionScope.self
    )
    self.usePassboltStoredProperty(
      UseLastUsedHomePresentationAsDefaultStoredPropertyDescription.self,
      in: SessionScope.self
    )
    self.usePassboltStoredProperty(
      DefaultHomeModeStoredPropertyDescription.self,
      in: SessionScope.self
    )
    // kept registered only to migrate already stored values away from user defaults
    self.usePassboltStoredProperty(
      PassphraseWipeOnBackgroundStoredPropertyDescription.self,
      in: SessionScope.self
    )
    self.usePassboltKeychainStoredProperty(
      PassphraseWipeOnBackgroundKeychainPropertyDescription.self,
      in: SessionScope.self
    )
  }
}

internal typealias DefaultHomeModeStoredProperty = StoredProperty<DefaultHomeModeStoredPropertyDescription>

internal enum DefaultHomeModeStoredPropertyDescription: StoredPropertyDescription {

  public typealias Value = String

  public static var key: OSStoredPropertyKey { "DefaultHomePresentationProperty" }
}

internal typealias UseLastUsedHomePresentationAsDefaultStoredProperty = StoredProperty<
  UseLastUsedHomePresentationAsDefaultStoredPropertyDescription
>

internal enum UseLastUsedHomePresentationAsDefaultStoredPropertyDescription: StoredPropertyDescription {

  public typealias Value = Bool

  public static var key: OSStoredPropertyKey { "UseLastUsedHomePresentationAsDefault" }
}

internal typealias PassphraseWipeOnBackgroundStoredProperty = StoredProperty<
  PassphraseWipeOnBackgroundStoredPropertyDescription
>

/// Legacy, user defaults backed storage of the setting.
/// Kept only to migrate already stored values to `PassphraseWipeOnBackgroundKeychainProperty`.
internal enum PassphraseWipeOnBackgroundStoredPropertyDescription: StoredPropertyDescription {

  public typealias Value = Bool

  public static var key: OSStoredPropertyKey { "PassphraseWipeOnBackground" }
}

internal typealias PassphraseWipeOnBackgroundKeychainProperty = KeychainStoredProperty<
  PassphraseWipeOnBackgroundKeychainPropertyDescription
>

internal enum PassphraseWipeOnBackgroundKeychainPropertyDescription: KeychainStoredPropertyDescription {

  public typealias Value = Bool

  public static var key: OSKeychainQuery.Key { "passphraseWipeOnBackground" }
}
