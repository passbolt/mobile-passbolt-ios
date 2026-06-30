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

  /// Continuations awaiting the full dismissal transition of a sheet, keyed by destination id.
  private var dismissalContinuations: [NavigationDestinationIdentifier: [CheckedContinuation<Void, Never>]] = [:]

  /// Id of the full sheet currently performing its dismissal transition, if any.
  private var dismissingSheetID: NavigationDestinationIdentifier? = nil

  /// Id of the partial sheet currently performing its dismissal transition, if any.
  private var dismissingPartialSheetID: NavigationDestinationIdentifier? = nil

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

  /// Dismisses the sheet or partial sheet with the given identifier and suspends until its
  /// dismissal transition has fully completed (the sheet's `onDismiss` has fired).
  ///
  /// This lets callers safely present something else (e.g. an alert) only once the sheet is
  /// actually gone - presenting while a sheet is still mid-dismiss is silently dropped by UIKit
  /// on iOS 16/17. Falls back to a plain `dismiss(with:)` (returning immediately) for non-sheet
  /// destinations or when no matching sheet is presented.
  internal func dismissAndWaitForCompletion(id: NavigationDestinationIdentifier) async {
    let dismissesFullSheet: Bool = presentedSheet?.id == id
    let dismissesPartialSheet: Bool = presentedPartialSheet?.id == id
    guard dismissesFullSheet || dismissesPartialSheet
    else {
      dismiss(with: id)
      return
    }
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      // Register the awaiter before triggering dismissal so `onDismiss` can never
      // fire before the continuation has been stored.
      dismissalContinuations[id, default: []].append(continuation)
      unregister(id)
      if dismissesFullSheet {
        dismissingSheetID = id
        presentedSheet = nil
      }
      else {
        dismissingPartialSheetID = id
        presentedPartialSheet = nil
      }
    }
  }

  /// Called by the container once a full sheet has finished its dismissal transition.
  internal func sheetDidFinishDismissing() {
    guard let id = dismissingSheetID else { return }
    dismissingSheetID = nil
    resumeDismissalAwaiters(of: id)
  }

  /// Called by the container once a partial sheet has finished its dismissal transition.
  internal func partialSheetDidFinishDismissing() {
    guard let id = dismissingPartialSheetID else { return }
    dismissingPartialSheetID = nil
    resumeDismissalAwaiters(of: id)
  }

  private func resumeDismissalAwaiters(of id: NavigationDestinationIdentifier) {
    guard let continuations = dismissalContinuations.removeValue(forKey: id) else { return }
    for continuation in continuations {
      continuation.resume()
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
