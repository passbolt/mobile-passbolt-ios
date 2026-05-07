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

import SwiftUI

/// Observable object managing SwiftUI navigation state.
/// Tracks the navigation path, presented sheets, and maintains a registry
/// of active destinations for uniqueness checks.
@MainActor
public final class NavigationState: ObservableObject {

  @Published public var path: NavigationPath = NavigationPath()
  @Published public var presentedSheet: AnyNavigationItem? = nil
  @Published public var presentedPartialSheet: AnyNavigationItem? = nil
  @Published public var presentedAlert: AlertItem? = nil

  /// Registry tracking active navigation destinations and their count.
  /// Used for uniqueness checks and determining if a destination exists.
  private var destinationRegistry: [NavigationDestinationIdentifier: Int] = [:]

  /// Tracks the order of items in the path for index-based operations.
  private var pathItems: [AnyNavigationItem] = []

  public init() {}

  /// Checks if a destination with the given identifier currently exists in the navigation state.
  public func exists(with id: NavigationDestinationIdentifier) -> Bool {
    (destinationRegistry[id] ?? 0) > 0
  }

  /// Registers a destination as active in the registry.
  internal func register(_ id: NavigationDestinationIdentifier) {
    destinationRegistry[id, default: 0] += 1
  }

  /// Unregisters a destination from the registry.
  internal func unregister(_ id: NavigationDestinationIdentifier) {
    guard let count = destinationRegistry[id], count > 0 else { return }
    if count == 1 {
      destinationRegistry.removeValue(forKey: id)
    }
    else {
      destinationRegistry[id] = count - 1
    }
  }

  /// Pushes a navigation item onto the path.
  internal func push(_ item: AnyNavigationItem, unique: Bool) throws {
    if unique && exists(with: item.id) {
      throw
        InternalInconsistency
        .error("Duplicate navigation!")
        .asAssertionFailure()
    }
    register(item.id)
    pathItems.append(item)
    path.append(item)
  }

  /// Presents a sheet with the given item.
  internal func presentSheet(_ item: AnyNavigationItem, unique: Bool) throws {
    if unique && exists(with: item.id) {
      throw
        InternalInconsistency
        .error("Duplicate navigation!")
        .asAssertionFailure()
    }
    register(item.id)
    presentedSheet = item
  }

  /// Presents a partial sheet with the given item.
  internal func presentPartialSheet(_ item: AnyNavigationItem, unique: Bool) throws {
    if unique && exists(with: item.id) {
      throw
        InternalInconsistency
        .error("Duplicate navigation!")
        .asAssertionFailure()
    }
    register(item.id)
    presentedPartialSheet = item
  }

  /// Presents an alert.
  internal func presentAlert(_ item: AlertItem) {
    presentedAlert = item
  }

  /// Dismisses a destination by identifier, popping back to the view before it.
  /// This behaves like UIKit's popToViewController - it removes the target AND everything above it.
  internal func dismiss(with id: NavigationDestinationIdentifier) {
    // Check sheets first
    if presentedSheet?.id == id {
      unregister(id)
      presentedSheet = nil
      return
    }

    if presentedPartialSheet?.id == id {
      unregister(id)
      presentedPartialSheet = nil
      return
    }

    // Check path items - pop to before the dismissed item (like UIKit's popToViewController)
    if let index = pathItems.lastIndex(where: { $0.id == id }) {
      // Unregister all items from index onwards
      for i in index ..< pathItems.count {
        unregister(pathItems[i].id)
      }
      // Remove all items from index onwards
      pathItems.removeSubrange(index...)
      // Rebuild path from remaining items
      path = NavigationPath()
      for item in pathItems {
        path.append(item)
      }
    }
  }

  /// Pops the navigation stack to root.
  public func popToRoot() {
    for item in pathItems {
      unregister(item.id)
    }
    pathItems.removeAll()
    path = NavigationPath()
  }

  /// Called when a sheet is dismissed externally (e.g., by swipe gesture).
  internal func sheetDismissed() {
    if let sheet = presentedSheet {
      unregister(sheet.id)
      presentedSheet = nil
    }
  }

  /// Called when a partial sheet is dismissed externally.
  internal func partialSheetDismissed() {
    if let sheet = presentedPartialSheet {
      unregister(sheet.id)
      presentedPartialSheet = nil
    }
  }

  /// Called when an alert is dismissed.
  internal func alertDismissed() {
    presentedAlert = nil
  }

  /// Synchronizes internal state when the NavigationPath changes externally (e.g., back button).
  internal func synchronizeWithPath(newCount: Int) {
    while pathItems.count > newCount {
      if let removed = pathItems.popLast() {
        unregister(removed.id)
      }
    }
  }
}
