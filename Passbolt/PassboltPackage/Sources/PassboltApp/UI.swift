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

import UIComponents

@MainActor
public final class UI {

  private var windows: Dictionary<String, Window> = .init()
  private let features: FeatureFactory
  private let components: UIComponentFactory

  public init(
    features: FeatureFactory
  ) {
    self.features = features
    self.components = UIComponentFactory(features: features)
  }
}

extension UI {

  public func prepare(
    _ scene: UIScene,
    in session: UISceneSession,
    with options: UIScene.ConnectionOptions
  ) {
    switch scene {
    case let windowScene as UIWindowScene:
      MainActor.execute {
        let cancellables: Cancellables = .init()
        let window: Window = await self.prepareWindow(
          for: windowScene,
          in: session,
          with: options,
          cancellables: cancellables
        )
        if self.windows.isEmpty {
          window.isActive = true
        }
        else {
          /* */
        }
        self.windows[windowScene.session.persistentIdentifier] = window
      }

    case _:
      unreachable("Unsupported scene type")
    }
  }

  public func resume(_ scene: UIScene) {
    windows[scene.session.persistentIdentifier]?.isActive = true
  }

  public func suspend(_ scene: UIScene) {
    windows[scene.session.persistentIdentifier]?.isActive = false
  }

  public func close(_ scene: UIScene) {
    windows[scene.session.persistentIdentifier]?.isActive = false
    windows[scene.session.persistentIdentifier] = nil
  }
}

extension UI {

  private func prepareWindow(
    for scene: UIWindowScene,
    in session: UISceneSession,
    with options: UIScene.ConnectionOptions,
    cancellables: Cancellables
  ) async -> Window {
    do {
      return try await Window(
        in: scene,
        using: WindowController.instance(
          with: features,
          cancellables: cancellables
        ),
        within: components,
        rootViewController:
          await components
          .instance(of: SplashScreenViewController.self),
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError()
    }
  }
}
