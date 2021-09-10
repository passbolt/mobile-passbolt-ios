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

import Crypto
import Combine
import Features
import Foundation
import NFC
import PassboltApp

internal struct Application {
  
  internal let ui: UI
  private let features: FeatureFactory
  
  internal init(
    environment: Environment = Environment(
      Time.live,
      UUIDGenerator.live,
      Logger.live,
      Networking.foundation(),
      Preferences.sharedUserDefaults(),
      Keychain.live(),
      Biometrics.live,
      Camera.live(),
      ExternalURLOpener.live(),
      AppLifeCycle.application(),
      PGP.gopenPGP(),
      SignatureVerfication.rssha256(),
      MDMConfig.live,
      Database.sqlite(),
      Files.live,
      AutoFillExtension.live(),
      SystemPasteboard.uiPasteboard(),
      Yubikey.live()
    )
  ) {
    let features: FeatureFactory = .init(environment: environment)
    #if DEBUG
    features.environment.use(
      features
        .environment
        .networking
        .withLogs(using: features.instance())
    )
    #endif
    
    self.ui = UI(features: features)
    self.features = features
  }
}

extension Application {
  
  internal func initialize() -> Bool {
    features.instance(of: Initialization.self).initialize()
  }
}

extension Application {
  
  internal static let shared: Application = .init()
}

