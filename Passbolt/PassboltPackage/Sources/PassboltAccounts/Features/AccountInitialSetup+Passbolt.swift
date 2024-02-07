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

// MARK: Implementation

extension AccountInitialSetup {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let accountPreferences: AccountPreferences = try features.instance()

    #warning("TODO: refine with account related storage")
    let unfinishedSetupElementsProperty: AccountInitialSetupUnfinishedItemsStoredProperty = try features.instance()

    let osExtensions: OSExtensions = features.instance()
    let osBiometry: OSBiometry = features.instance()

    @Sendable func unfinishedSetupElements() async -> Set<SetupElement> {
      var unfinishedElements: Set<SetupElement> =
        unfinishedSetupElementsProperty
        .get(withDefault: [])
        .compactMap(SetupElement.init(rawValue:))
        .asSet()

      if await osExtensions.autofillExtensionEnabled() {
        unfinishedElements.remove(.autofill)
      }  // else continue

      if osBiometry.availability() == .unavailable || accountPreferences.isPassphraseStored() {
        unfinishedElements.remove(.biometrics)
      }  // else continue

      if unfinishedElements.isEmpty {
        unfinishedSetupElementsProperty
          .set(to: .none)
      }
      else {
        unfinishedSetupElementsProperty
          .set(to: unfinishedElements.map(\.rawValue))
      }

      return unfinishedElements
    }

    @Sendable func completeSetup(
      of element: SetupElement
    ) {
      var unfinishedElements: Set<SetupElement> =
        unfinishedSetupElementsProperty
        .get(withDefault: [])
        .compactMap(SetupElement.init(rawValue:))
        .asSet()

      unfinishedElements.remove(element)

      if unfinishedElements.isEmpty {
        unfinishedSetupElementsProperty
          .set(to: .none)
      }
      else {
        unfinishedSetupElementsProperty
          .set(to: unfinishedElements.map(\.rawValue))
      }
    }

    return .init(
      unfinishedSetupElements: unfinishedSetupElements,
      completeSetup: completeSetup(of:)
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccountInitialSetup() {
    self.use(
      .disposable(
        AccountInitialSetup.self,
        load: AccountInitialSetup.load(features:)
      ),
      in: SessionScope.self
    )
    self.usePassboltStoredProperty(
      AccountInitialSetupUnfinishedItemsStoredPropertyDescription.self,
      in: SessionScope.self
    )
  }
}

internal typealias AccountInitialSetupUnfinishedItemsStoredProperty = StoredProperty<
  AccountInitialSetupUnfinishedItemsStoredPropertyDescription
>

internal enum AccountInitialSetupUnfinishedItemsStoredPropertyDescription: StoredPropertyDescription {

  public typealias Value = Array<String>

  public static var key: OSStoredPropertyKey { "unfinishedSetup" }
}
