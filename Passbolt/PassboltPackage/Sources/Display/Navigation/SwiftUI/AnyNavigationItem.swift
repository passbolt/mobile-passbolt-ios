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

/// Type-erased navigation item for use with NavigationPath.
/// Wraps a destination view and its identifier for routing.
public struct AnyNavigationItem: Identifiable, Hashable, @unchecked Sendable {

  public let id: NavigationDestinationIdentifier

  /// Unique instance identifier for Hashable conformance.
  /// This ensures each navigation item is unique even for non-unique destinations.
  private let instanceID: UUID

  /// The type-erased view to display.
  private let wrappedView: AnyView

  public init<Content: View>(
    id: NavigationDestinationIdentifier,
    @ViewBuilder content: () -> Content
  ) {
    self.id = id
    self.instanceID = UUID()
    self.wrappedView = AnyView(content())
  }

  @MainActor
  public func makeView() -> some View {
    NavigationItemContentView(
      itemID: instanceID,
      wrappedView: wrappedView
    )
    .equatable()
  }

  public static func == (lhs: AnyNavigationItem, rhs: AnyNavigationItem) -> Bool {
    lhs.instanceID == rhs.instanceID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(instanceID)
  }
}

/// Concrete view wrapper enabling Equatable-based body skip optimization.
/// Prevents toolbar/overlay modifier accumulation when NavigationStack re-evaluates.
public struct NavigationItemContentView: View, Equatable {

  private let itemID: UUID
  private let wrappedView: AnyView

  internal init(
    itemID: UUID,
    wrappedView: AnyView
  ) {
    self.itemID = itemID
    self.wrappedView = wrappedView
  }

  public var body: some View {
    wrappedView
  }

  nonisolated public static func == (
    lhs: NavigationItemContentView,
    rhs: NavigationItemContentView
  ) -> Bool {
    lhs.itemID == rhs.itemID
  }
}

/// Alert item for SwiftUI alert presentation.
public struct AlertItem: Identifiable {

  public let id: NavigationDestinationIdentifier
  public let title: String
  public let message: String?
  public let actions: [SwiftUIAlertAction]

  public init(
    id: NavigationDestinationIdentifier,
    title: String,
    message: String? = nil,
    actions: [SwiftUIAlertAction]
  ) {
    self.id = id
    self.title = title
    self.message = message
    self.actions = actions
  }
}

/// Alert action for SwiftUI alerts.
public struct SwiftUIAlertAction: Identifiable {

  public let id: UUID = UUID()
  public let title: String
  public let role: SwiftUIAlertActionRole
  public let action: () -> Void

  public init(
    title: String,
    role: SwiftUIAlertActionRole = .default,
    action: @Sendable @escaping () -> Void = {}
  ) {
    self.title = title
    self.role = role
    self.action = action
  }
}

/// Role for alert actions.
public enum SwiftUIAlertActionRole {
  case `default`
  case cancel
  case destructive

  var buttonRole: ButtonRole? {
    switch self {
    case .default:
      return nil
    case .cancel:
      return .cancel
    case .destructive:
      return .destructive
    }
  }
}
