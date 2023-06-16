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
import OSFeatures
import Session

// MARK: - Implementation

extension AccountPreferences {

  @MainActor fileprivate static func load(
    features: Features,
    context account: Account,
    cancellables: Cancellables
  ) throws -> Self {

    let accountData: AccountData = try features.instance(context: account)
    let accountsDataStore: AccountsDataStore = try features.instance()
    let sessionPassphrase: SessionPassphrase = try features.instance(context: .init(account: account))

    @Sendable nonisolated func setLocalAccountLabel(
      _ label: String
    ) throws {
      var profile: AccountProfile =
        try accountsDataStore
        .loadAccountProfile(account.localID)
      profile.label = label
      try accountsDataStore
        .updateAccountProfile(profile)
      accountData.updatesSource.sendUpdate()
    }

    @Sendable nonisolated func isPassphraseStored() -> Bool {
      accountsDataStore.isAccountPassphraseStored(account.localID)
    }

    @Sendable nonisolated func storePassphrase(
      _ store: Bool
    ) async throws {
      try await sessionPassphrase.storeWithBiometry(store)
      accountData.updatesSource.sendUpdate()
    }

    let useLastHomePresentationAsDefaultProperty: StoredProperty<Bool> =
      try features
      .instance(
        context: "UseLastUsedHomePresentationAsDefault-\(account)"
      )
    let useLastHomePresentationAsDefault: StateBinding<Bool> = useLastHomePresentationAsDefaultProperty
      .binding
      .convert(
        read: unwrapped(default: true),
        write: identity
      )

    let defaultHomePresentationProperty: StoredProperty<String> =
      try features
      .instance(
        context: "DefaultHomePresentationProperty-\(account)"
      )
    let defaultHomePresentation: StateBinding<HomePresentationMode> = defaultHomePresentationProperty
      .binding
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

    return Self(
      updates: accountData.updates,
      setLocalAccountLabel: setLocalAccountLabel(_:),
      isPassphraseStored: isPassphraseStored,
      storePassphrase: storePassphrase(_:),
      useLastHomePresentationAsDefault: useLastHomePresentationAsDefault,
      defaultHomePresentation: defaultHomePresentation
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountPreferences() {
    self.use(
      .lazyLoaded(
        AccountPreferences.self,
        load: AccountPreferences.load(features:context:cancellables:)
      )
    )
  }
}
