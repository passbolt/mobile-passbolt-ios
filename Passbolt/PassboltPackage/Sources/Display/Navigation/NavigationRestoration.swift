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

public struct NavigationRestoration: Sendable {

  public var saveCurrent: @Sendable () async throws -> Void
  public var canRestore: @Sendable () async throws -> Bool
  public var restore: @Sendable () async throws -> Void
}

extension NavigationRestoration: LoadableFeature {

  public static var placeholder: Self {
    .init(
      saveCurrent: unimplemented0(),
      canRestore: unimplemented0(),
      restore: unimplemented0()
    )
  }

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let rootNavigation: RootNavigation = try features.instance()
    let restorationPoint: CriticalState<(item: AnyNavigationItem, useNavigationStack: Bool)?> = .init(.none)

    return .init(
      saveCurrent: { [rootNavigation] in
        await MainActor.run {
          if let currentRoot: AnyNavigationItem = rootNavigation.state.currentRoot {
            restorationPoint.set((currentRoot, rootNavigation.state.useNavigationStack))
          }
        }
      },
      canRestore: {
        restorationPoint.get() != nil
      },
      restore: { [rootNavigation] in
        guard let saved = restorationPoint.get() else {
          return
        }
        await MainActor.run {
          rootNavigation.state.setRoot(saved.item, withNavigationStack: saved.useNavigationStack)
        }
        restorationPoint.set(.none)
      }
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveNavigationRestoration() {
    self.use(
      .lazyLoaded(
        NavigationRestoration.self,
        load: { try NavigationRestoration.load(features: $0) }
      )
    )
  }
}
