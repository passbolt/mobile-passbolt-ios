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

import class AuthenticationServices.ASCredentialProviderViewController
import Features
import NetworkClient
import PassboltExtension
import UIComponents

internal struct ApplicationExtension {
  
  internal let ui: UI
  private let features: FeatureFactory
  
  internal init(
    rootViewController: ASCredentialProviderViewController,
    environment: RootEnvironment = RootEnvironment(
      time: .live,
      uuidGenerator: .live,
      logger: .live,
      networking: .foundation(),
      preferences: .sharedUserDefaults(),
      keychain: .live(),
      biometrics: .live,
      camera: .live(),
      urlOpener: .live(),
      appLifeCycle: .live(),
      pgp: .gopenPGP(),
      signatureVerification: .RSSHA256()
    )
  ) {
    let features: FeatureFactory = .init(environment: environment)
    #if DEBUG
    features.environment.networking = features
      .environment
      .networking
      .withLogs(using: features.instance())
    #endif
    
    #warning("TODO: [PAS-134] to complete - other methods")
    features.use(
      AutofillExtensionContext(
        completeExtensionConfiguration: {
          DispatchQueue
            .main
            .async(
              execute: rootViewController
                .extensionContext
                .completeExtensionConfigurationRequest
            )
        }
      )
    )
    
    self.ui = UI(
      rootViewController: rootViewController,
      features: features
    )
    self.features = features
  }
}

extension ApplicationExtension {
  
  internal func initialize() {
    features.instance(of: Initialization.self).initialize()
  }
}
