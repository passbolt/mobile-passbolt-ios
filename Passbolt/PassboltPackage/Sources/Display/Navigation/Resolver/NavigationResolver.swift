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

// Current implementation is not final.
// It is hacky to quickly utilize existing
// navigation and allow mixing target interface
// with existing stuff. It will have to be rewritten
// from scratch in future. However provided interface
// should be kept unchanged (`NavigationTo`).
internal struct NavigationResolver {
  fileprivate var rootAnchorProvider: RootAnchorProvider?

  internal init(rootAnchorProvider: RootAnchorProvider?) {
    self.rootAnchorProvider = rootAnchorProvider
  }
}

extension NavigationResolver: LoadableFeature {

  #if DEBUG
  internal static var placeholder: Self {
    unimplemented("This type should not be used in tests at all.")
  }
  #endif
}

extension NavigationResolver {

  @MainActor internal func dynamicLegacySheetDetent(
    for anchor: NavigationAnchor
  ) -> UISheetPresentationController.Detent {
    .custom { context in
      min(
        anchor.view.intrinsicContentSize.height,
        context.maximumDetentValue
      )
    }
  }

  @MainActor internal func exists(
    with identifier: NavigationDestinationIdentifier
  ) -> Bool {
    self.leafAnchor(with: identifier) != nil
  }

  @MainActor internal func push(
    _ anchor: NavigationAnchor,
    unique: Bool,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    guard let identifier: NavigationDestinationIdentifier = anchor.destinationIdentifier
    else {
      throw
        InternalInconsistency
        .error(
          "Pushed anchor has to have identifier!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    guard !unique || !self.exists(with: identifier)
    else {
      throw
        InternalInconsistency
        .error(
          "Duplicate navigation!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    try await self.activeLeafAnchor()?
      .push(
        anchor,
        animated: animated,
        file: file,
        line: line
      )
  }

  @MainActor internal func pop(
    to identifier: NavigationDestinationIdentifier,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    try await self.rootAnchor()?
      .pop(
        to: identifier,
        animated: animated,
        file: file,
        line: line
      )
  }

  @MainActor internal func present(
    _ anchor: NavigationAnchor,
    unique: Bool,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    guard let identifier: NavigationDestinationIdentifier = anchor.destinationIdentifier
    else {
      throw
        InternalInconsistency
        .error(
          "Presented anchor has to have identifier!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    guard !unique || !self.exists(with: identifier)
    else {
      throw
        InternalInconsistency
        .error(
          "Duplicate navigation!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    await self.activeLeafAnchor()?
      .present(
        anchor,
        animated: animated,
        file: file,
        line: line
      )
  }

  @MainActor internal func dismiss(
    with identifier: NavigationDestinationIdentifier,
    animated: Bool,
    file: StaticString,
    line: UInt
  ) async throws {
    await self.rootAnchor()?
      .dismiss(
        with: identifier,
        animated: animated,
        file: file,
        line: line
      )
  }

  // To be used only with legacy tabs,
  // ignores anchor indentifiers using types instead.
  @MainActor internal func legacyTabSwitch<Tab>(
    to: Tab.Type,
    file: StaticString,
    line: UInt
  ) async throws
  where Tab: UIViewController {
    guard let tabs: UITabBarController = self.activeLeafAnchor()?.navigationTabs
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid navigation - missing tabs!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    guard let idx: Int = tabs.viewControllers?.firstIndex(where: { $0 is Tab })
    else {
      throw
        InternalInconsistency
        .error(
          "Invalid navigation - missing tab item!",
          file: file,
          line: line
        )
        .asAssertionFailure()
    }

    tabs.selectedIndex = idx
  }
}
extension NavigationResolver {

  @MainActor fileprivate func rootAnchor() -> NavigationAnchor? {
    rootAnchorProvider?.rootAnchor()
  }

  @MainActor fileprivate func leafAnchor(
    with identifier: NavigationDestinationIdentifier
  ) -> NavigationAnchor? {
    self.rootAnchor()?
      .leafAnchor(with: identifier)
  }

  @MainActor fileprivate func activeLeafAnchor() -> NavigationAnchor? {
    self.rootAnchor()?.leafAnchor
  }
}

extension NavigationResolver {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let rootAnchorProvider: RootAnchorProvider = try features.instance()
    return .init(
      rootAnchorProvider: rootAnchorProvider
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useLiveNavigationResolver() {
    self.use(
      .disposable(
        NavigationResolver.self,
        load: NavigationResolver.load(features:)
      )
    )
  }
}

internal struct RootAnchorProvider {

  /// Provides the root navigation anchor.
  /// - Returns: The root navigation anchor.
  internal var rootAnchor: () -> NavigationAnchor?

  internal init(
    rootAnchor: @escaping () -> NavigationAnchor?
  ) {
    self.rootAnchor = rootAnchor
  }
}

extension RootAnchorProvider: LoadableFeature {

  #if DEBUG
  public static var placeholder: Self {
    unimplemented("This type should not be used in tests at all.")
  }
  #endif

  internal static func load(
    features: Features
  ) throws -> Self {
    .init(
      rootAnchor: {
        UIApplication.shared
          .connectedScenes
          .compactMap({ scene in
            (scene as? UIWindowScene)?.keyWindow?.rootViewController
          })
          .first
      }
    )
  }

  internal static func loadExtension(
    feature: Features
  ) throws -> Self {
    .init(
      rootAnchor: {
        // This is temorary solution for autofill extension. Has to be refactored once navigation is moved entirely to SwiftUI.
        UIApplication.shared.keyWindow?.rootViewController?.children.first?.children.first?.children.first
      }
    )
  }
}

extension FeaturesRegistry {

  public mutating func useApplicationRootAnchorProvider() {
    self.use(
      .disposable(
        RootAnchorProvider.self,
        load: RootAnchorProvider.load(features:)
      )
    )
  }

  public mutating func useExtensionRootAnchorProvider() {
    self.use(
      .lazyLoaded(
        RootAnchorProvider.self,
        load: RootAnchorProvider.loadExtension(feature:)
      )
    )
  }
}
