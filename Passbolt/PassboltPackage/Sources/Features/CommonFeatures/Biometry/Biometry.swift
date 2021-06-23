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

import Commons
import Environment

public struct Biometry {
  
  public var biometricsStatePublisher: () -> AnyPublisher<Biometrics.State, Never>
}

extension Biometry: Feature {
  
  public typealias Environment = (
    biometrics: Biometrics,
    appLifeCycle: AppLifeCycle
  )
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      biometrics: rootEnvironment.biometrics,
      appLifeCycle: rootEnvironment.appLifeCycle
    )
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    
    let biometricsStateSubject: CurrentValueSubject<Biometrics.State, Never> = .init(
      environment
        .biometrics
        .checkBiometricsState()
    )
    
    environment
      .appLifeCycle
      .lifeCyclePublisher()
      .removeDuplicates()
      // Looking for sequence of didEnterBackground and didBecomeActive which indicates exiting
      // and goind back to the application, we check biometrics state again if it ha changed or not
      .scan((Optional<Void>.none, AppLifeCycle.Transition.didBecomeActive), { prev, next in
        if prev.1 == .didEnterBackground && next == .didBecomeActive {
          return (Void(), next)
        } else {
          return (nil, next)
        }
      })
      .compactMap(\.0)
      .sink {
        biometricsStateSubject.send(
          environment
            .biometrics
            .checkBiometricsState()
        )
      }
      .store(in: cancellables)
    
    func biometricsStatePublisher() -> AnyPublisher<Biometrics.State, Never> {
      biometricsStateSubject
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    return Self(
      biometricsStatePublisher: biometricsStatePublisher
    )
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      biometricsStatePublisher: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

