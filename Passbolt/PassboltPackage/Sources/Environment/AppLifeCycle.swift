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
import UIKit

public struct AppLifeCycle: EnvironmentElement {

  public enum Transition: Equatable {

    case didBecomeActive
    case willResignActive
    case didEnterBackground
    case willEnterForeground
    case willTerminate
  }

  public var lifeCyclePublisher: () -> AnyPublisher<Transition, Never>
}

extension AppLifeCycle {

  public static func application() -> Self {
    let lifeCyclePublisher: AnyPublisher<Transition, Never> = Publishers.MergeMany(
      NotificationCenter
        .default
        .publisher(for: UIApplication.didBecomeActiveNotification)
        .map { _ in Transition.didBecomeActive },
      NotificationCenter
        .default
        .publisher(for: UIApplication.willResignActiveNotification)
        .map { _ in Transition.willResignActive },
      NotificationCenter
        .default
        .publisher(for: UIApplication.didEnterBackgroundNotification)
        .map { _ in Transition.didEnterBackground },
      NotificationCenter
        .default
        .publisher(for: UIApplication.willEnterForegroundNotification)
        .map { _ in Transition.willEnterForeground },
      NotificationCenter
        .default
        .publisher(for: UIApplication.willTerminateNotification)
        .map { _ in Transition.willTerminate }
    )
    .removeDuplicates()
    .share()
    .eraseToAnyPublisher()
    return Self(
      lifeCyclePublisher: { lifeCyclePublisher }
    )
  }
}

extension AppLifeCycle {

  // Autofill extension empty lifecycle - there's currently no way
  // of determining the actual state of the app extension.
  public static func autoFillExtension() -> Self {
    Self(
      lifeCyclePublisher: Empty<Transition, Never>().eraseToAnyPublisher
    )
  }
}

extension AppEnvironment {

  public var appLifeCycle: AppLifeCycle {
    get { element(AppLifeCycle.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension AppLifeCycle {
  public static var placeholder: Self {
    Self(
      lifeCyclePublisher: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
