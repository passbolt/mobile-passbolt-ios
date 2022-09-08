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

import Features
import UIComponents

@available(*, deprecated, message: "Please switch to `NavigationTree`")
internal struct LegacyNavigationBridge {

  internal let bridgeComponent: () async -> AnyUIComponent?
}

extension LegacyNavigationBridge: LoadableContextlessFeature {

  #if DEBUG
  internal static var placeholder: Self {
    .init(
      bridgeComponent: { .none }  // NOP
    )
  }
  #endif
}

extension FeatureFactory {

  internal func useLiveLegacyNavigationBridge() {
    self.use(
      .lazyLoaded(
        LegacyNavigationBridge.self,
        load: { _, context in
          @MainActor func topmostViewComponent() -> AnyUIComponent? {
            guard
              var current: UIViewController = UIApplication.shared.connectedScenes.compactMap({ scene in
                (scene as? UIWindowScene)?.keyWindow?.rootViewController
              })
              .first
            else { return .none }

            var candidate: AnyUIComponent?
            while true {
              if let tabs: UITabBarController = current as? UITabBarController {
                if let presented: UIViewController = tabs.presentedViewController {
                  current = presented
                }
                else if let viewControllers: Array<UIViewController> = tabs.viewControllers {
                  current = viewControllers[tabs.selectedIndex]
                }
                else {
                  break
                }
              }
              else if let navigation: UINavigationController = current as? UINavigationController {
                if let presented: UIViewController = navigation.presentedViewController {
                  current = presented
                }
                else if let last: UIViewController = navigation.viewControllers.last {
                  current = last
                }
                else {
                  break
                }
              }
              else if let presented: UIViewController = current.presentedViewController {
                current = presented
              }
              else {
                break
              }

              candidate = current as? AnyUIComponent ?? candidate
            }

            return candidate
          }

          return LegacyNavigationBridge(
            bridgeComponent: topmostViewComponent
          )
        }
      )
    )
  }
}
