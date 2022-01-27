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
import CommonModels
import NetworkClient
import UIComponents

internal struct MFARootController {

  internal var mfaProviderPublisher: () -> AnyPublisher<MFAProvider, TheErrorLegacy>
  internal var navigateToOtherMFA: () -> Void
  internal var closeSession: () -> Void
  internal var isProviderSwitchingAvailable: () -> Bool
}

extension MFARootController: UIController {

  internal typealias Context = Array<MFAProvider>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> MFARootController {

    let accountSession: AccountSession = features.instance()
    let mfaProviderSubject: CurrentValueSubject<MFAProvider?, TheErrorLegacy> = .init(context.first)

    func mfaProviderPublisher() -> AnyPublisher<MFAProvider, TheErrorLegacy> {
      mfaProviderSubject
        .handleEvents(receiveOutput: { provider in
          if provider == nil {
            closeSession()
          }
          else {
            /* NOP */
          }
        })
        .filterMapOptional()
        .eraseToAnyPublisher()
    }

    func navigateToOtherMFA() {
      let providers: Array<MFAProvider> = context

      guard
        let currentProvider: MFAProvider = mfaProviderSubject.value,
        let currentIndex: Array.Index = providers.firstIndex(of: currentProvider)
      else { return }

      let nextIndex: Array.Index =
        currentIndex.advanced(by: 1) < providers.count ? currentIndex.advanced(by: 1) : providers.startIndex

      let nextProvider: MFAProvider = providers[nextIndex]

      mfaProviderSubject.send(nextProvider)
    }

    func closeSession() {
      accountSession.close()
    }

    func isProviderSwitchingAvailable() -> Bool {
      context.count > 1
    }

    return Self(
      mfaProviderPublisher: mfaProviderPublisher,
      navigateToOtherMFA: navigateToOtherMFA,
      closeSession: closeSession,
      isProviderSwitchingAvailable: isProviderSwitchingAvailable
    )
  }
}
