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
import Features
import Session
import UICommons

public struct Initialization {

  public var initialize: @MainActor () -> Void
  public var featureUnload: @MainActor () async throws -> Void
}

extension Initialization: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()

    // swift-format-ignore: NoLeadingUnderscores
    @MainActor func _initialize(with features: FeatureFactory) async throws {
      diagnostics.diagnosticLog("Initializing the app extension...")
      defer { diagnostics.diagnosticLog("...app extension initialization completed!") }
      // initialize application extension features here
      analytics()
      // load features that require root scope
      try await features.loadIfNeeded(Diagnostics.self)
      try await features.loadIfNeeded(Executors.self)
      try await features.loadIfNeeded(LinkOpener.self)
      try await features.loadIfNeeded(OSPermissions.self)

      try await features.unload(Initialization.self)
    }
    let initialize: @MainActor () -> Void = { [unowned features] in
      setupApplicationAppearance()
      cancellables.executeOnMainActor {
        try await _initialize(with: features)
      }
    }

    @MainActor func featureUnload() async throws {
      // always succeeds
    }

    return Self(
      initialize: initialize,
      featureUnload: featureUnload
    )
  }
}

#if DEBUG
extension Initialization {

  public static var placeholder: Self {
    Self(
      initialize: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
