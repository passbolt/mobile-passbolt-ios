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

import CommonModels
import Environment

public struct Biometry {

  // publishes current value initially
  public var biometricsStatePublisher: () -> AnyPublisher<Biometrics.State, Never>
}

extension Biometry: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let biometrics: Biometrics = environment.biometrics
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle

    let biometricsStateSubject: CurrentValueSubject<Biometrics.State, Never> = .init(biometrics.checkBiometricsState())

    appLifeCycle
      .lifeCyclePublisher()
      // Looking for sequence of didEnterBackground and didBecomeActive which indicates exiting
      // and goind back to the application, we check biometrics state again if it has changed or not
      .scan((Optional<Void>.none, AppLifeCycle.Transition.didBecomeActive)) { prev, next in
        guard next == .didEnterBackground || next == .didBecomeActive
        else { return (nil, prev.1) }
        if prev.1 == .didEnterBackground && next == .didBecomeActive {
          return (Void(), next)
        }
        else {
          return (nil, next)
        }
      }
      .compactMap(\.0)
      .map(biometrics.checkBiometricsState)
      .sink { state in
        biometricsStateSubject.send(state)
      }
      .store(in: cancellables)

    let biometricsStatePublisher: AnyPublisher<Biometrics.State, Never> =
      biometricsStateSubject
      .removeDuplicates()
      .eraseToAnyPublisher()

    return Self(
      biometricsStatePublisher: { biometricsStatePublisher }
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      biometricsStatePublisher: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension Biometry {

  public var featureUnload: @MainActor () async throws -> Void { {} }
}
