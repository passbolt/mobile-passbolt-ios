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
import Session
import UIComponents

internal struct MFARootController {

  internal var mfaProviderPublisher: @MainActor () -> AnyPublisher<SessionMFAProvider, Error>
  internal var navigateToOtherMFA: @MainActor () -> Void
  internal var closeSession: @MainActor () -> Void
  internal var isProviderSwitchingAvailable: @MainActor () -> Bool
}

extension MFARootController: UIController {

  internal typealias Context = Array<SessionMFAProvider>

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> MFARootController {
    let session: Session = try await features.instance()
    let mfaProviderSubject: CurrentValueSubject<SessionMFAProvider?, Error> = .init(context.first)

    func mfaProviderPublisher() -> AnyPublisher<SessionMFAProvider, Error> {
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
      let providers: Array<SessionMFAProvider> = context

      guard
        let currentProvider: SessionMFAProvider = mfaProviderSubject.value,
        let currentIndex: Array.Index = providers.firstIndex(of: currentProvider)
      else { return }

      let nextIndex: Array.Index =
        currentIndex.advanced(by: 1) < providers.count ? currentIndex.advanced(by: 1) : providers.startIndex

      let nextProvider: SessionMFAProvider = providers[nextIndex]

      mfaProviderSubject.send(nextProvider)
    }

    func closeSession() {
      cancellables.executeAsync {
        await session.close(.none)
      }
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
