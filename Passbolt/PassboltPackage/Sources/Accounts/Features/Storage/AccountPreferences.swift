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

import Features

// MARK: - Interface

public struct AccountPreferences {

  public var useLastUsedHomePresentationAsDefault: ValueBinding<Bool>
  public var defaultHomePresentation: ValueBinding<HomePresentationMode>
}

extension AccountPreferences: LoadableFeature {

  public typealias Context = Account.LocalID
}

// MARK: - Implementation

extension AccountPreferences {

  @FeaturesActor fileprivate static func load(
    features: FeatureFactory,
    context accountLocalID: Account.LocalID,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let useLastUsedHomePresentationAsDefaultProperty: StoredProperty<Bool> =
      try await features
      .instance(
        context: "UseLastUsedHomePresentationAsDefault-\(accountLocalID)"
      )
    let defaultHomePresentationProperty: StoredProperty<String> =
      try await features
      .instance(
        context: "DefaultHomePresentationProperty-\(accountLocalID)"
      )

    return Self(
      useLastUsedHomePresentationAsDefault: useLastUsedHomePresentationAsDefaultProperty
        .binding
        .convert(
          get: unwrapped(default: true),
          set: identity
        ),
      defaultHomePresentation: defaultHomePresentationProperty
        .binding
        .convert(
          get: unwrappedMap(
            default: .plainResourcesList,
            mapping: {
              HomePresentationMode
                .init(rawValue: $0)
            }
          ),
          set: { $0.rawValue }
        )
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltAccountPreferences() {
    self.use(
      .lazyLoaded(
        AccountPreferences.self,
        load: AccountPreferences.load(features:context:cancellables:)
      )
    )
  }
}

#if DEBUG
extension AccountPreferences {

  public nonisolated static var placeholder: Self {
    Self(
      useLastUsedHomePresentationAsDefault: .placeholder,
      defaultHomePresentation: .placeholder
    )
  }
}
#endif
