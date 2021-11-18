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
import Darwin
import Features

public struct Initialization {

  public var initialize: () -> Void
  public var featureUnload: () -> Bool
}

extension Initialization: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let diagnostics: Diagnostics = features.instance()

    // swift-format-ignore: NoLeadingUnderscores
    func _initialize(with features: FeatureFactory) {
      diagnostics.diagnosticLog("Initializing the app extension...")
      defer { diagnostics.diagnosticLog("...app extension initialization completed!") }
      defer { features.unload(Initialization.self) }
      // initialize application extension features here
      analytics()
    }
    let initialize: () -> Void = { [unowned features] in
      _initialize(with: features)
    }

    func featureUnload() -> Bool {
      true  // always succeeds
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
      initialize: Commons.placeholder("You have to provide mocks for used methods"),
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
