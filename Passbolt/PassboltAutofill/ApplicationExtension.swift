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
import class AuthenticationServices.ASCredentialServiceIdentifier
import struct AuthenticationServices.ASExtensionError
import Crypto
import Features

import PassboltExtension
import UIComponents

@MainActor 
internal final class ApplicationExtension {
  
  private let ui: UI
  private let features: FeatureFactory
  private var requestedServiceIdentifiers: Array<AutofillExtensionContext.ServiceIdentifier> = .init()
  
  @MainActor internal init(
    rootViewController: ASCredentialProviderViewController
  ) {
    let environment: AppEnvironment = AppEnvironment(
      Time.live,
      UUIDGenerator.live,
      Preferences.sharedUserDefaults(),
      Keychain.live(),
      Biometrics.live,
      PGP.gopenPGP(),
      SignatureVerfication.rssha256(),
      MDMConfig.live,
      Files.live,
      AppLifeCycle.autoFillExtension(),
      Camera.live(),
      ExternalURLOpener.live(),
      YubiKey.unavailable(),
      Randomness.system(),
      AsyncExecutors.libDispatch(),
      AppMeta.live
    )
    let features: FeatureFactory = .init(environment: environment)
    // register features implementations
    features.usePassboltInitialization()

    self.ui = UI(
      rootViewController: rootViewController,
      features: features
    )
    self.features = features
    features.use(
      ConfigurationExtensionContext(
        completeExtensionConfiguration: {
          rootViewController
            .extensionContext
            .completeExtensionConfigurationRequest()
        }
      )
    )
    features.use(
      AutofillExtensionContext(
        completeWithCredential: { credential in
          rootViewController
            .extensionContext
            .completeRequest(
              withSelectedCredential: .init(
                user: credential.user,
                password: credential.password
              ),
              completionHandler: nil
            )
        },
        completeWithError: { error in
          rootViewController
            .extensionContext
            .cancelRequest(withError: error)
        },
        cancelAndCloseExtension: {
          rootViewController
            .extensionContext
            .cancelRequest(withError: ASExtensionError(.userCanceled))
        },
        requestedServiceIdentifiers: { [weak self] in
          self?.requestedServiceIdentifiers ?? .init()
        }
      )
    )
  }
}

extension ApplicationExtension {
  
  @MainActor internal func initialize() {
    self.features
      .instance(of: Initialization.self)
      .initialize()
  }
  
  internal func requestSuggestions(
    for identifiers: Array<ASCredentialServiceIdentifier>
  ) {
    assert(
      self.requestedServiceIdentifiers.isEmpty,
      "Requested suggestions should not change during extension lifetime"
    )
    self.requestedServiceIdentifiers = identifiers
      .map { identifier in
        AutofillExtensionContext.ServiceIdentifier(
          rawValue: identifier.identifier
        )
      }
  }

  internal func prepareCredentialList() {
    self.ui.prepareCredentialList()
  }

  internal func prepareInterfaceForExtensionConfiguration() {
    self.ui.prepareInterfaceForExtensionConfiguration()
  }
}
