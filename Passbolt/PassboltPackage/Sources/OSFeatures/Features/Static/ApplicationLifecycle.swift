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

public struct ApplicationLifecycle {

  public var lifecyclePublisher: () -> AnyPublisher<Transition, Never>
}

extension ApplicationLifecycle {

  public enum Transition: Equatable {

    case didBecomeActive
    case willResignActive
    case didEnterBackground
    case willEnterForeground
    case willTerminate
  }
}

extension ApplicationLifecycle: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      lifecyclePublisher: unimplemented0()
    )
  }
  #endif
}

extension ApplicationLifecycle {

  fileprivate static var live: Self {

    let lifecyclePublisher: AnyPublisher<Transition, Never>
    if isInExtensionContext {
      lifecyclePublisher = Empty<Transition, Never>().eraseToAnyPublisher()
    }
    else {
      lifecyclePublisher = Publishers.MergeMany(
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
    }

    return Self(
      lifecyclePublisher: { lifecyclePublisher }
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useApplicationLifecycle() {
    self.use(
      ApplicationLifecycle.live
    )
  }
}
