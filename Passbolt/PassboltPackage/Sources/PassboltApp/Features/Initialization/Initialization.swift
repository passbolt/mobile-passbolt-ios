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

import AccountSetup
import Accounts
import Features
import OSFeatures
import UICommons

public struct Initialization {

  public var initialize: @MainActor () -> Void
}

extension Initialization: LoadableFeature {

  @MainActor public static func load(
    using features: Features
  ) throws -> Initialization {
    let diagnostics: OSDiagnostics = features.instance()

    // swift-format-ignore: NoLeadingUnderscores
    @MainActor func initialize() {
      diagnostics.log(diagnostic: "Initializing the app...")
      defer { diagnostics.log(diagnostic: "...app initialization completed!") }
      setupApplicationAppearance()
      // initialize application extension features here
      analytics()
      do {
        // insert preconfigured accounts
        let accountInjection: AccountInjection = try features.instance()
        try accountInjection.injectPreconfiguredAccounts()
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    return Self(
      initialize: initialize
    )
  }

  #if DEBUG
  public static var placeholder: Self {
    Self(
      initialize: unimplemented()
    )
  }
  #endif
}

extension FeaturesRegistry {

  public mutating func usePassboltInitialization() {
    self.use(
      .disposable(
        Initialization.self,
        load: Initialization.load(using:)
      )
    )
  }
}
