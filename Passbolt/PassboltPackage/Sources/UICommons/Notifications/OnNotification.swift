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

private struct OnNotificationModifier: ViewModifier {

  private let notificationName: Notification.Name
  private let handler: @Sendable (Notification) async -> Void

  fileprivate init(
    notificationName: Notification.Name,
    handler: @escaping @Sendable (Notification) async -> Void
  ) {
    self.notificationName = notificationName
    self.handler = handler
  }

  fileprivate func body(content: Content) -> some View {
    content.task {
      for await notification in NotificationCenter.default.notifications(named: self.notificationName) {
        await handler(notification)
      }
    }
  }
}

extension View {

  /// Adds a handler for notifications with the specified name.
  /// - Parameters:
  ///  - notificationName: The name of the notifications to observe.
  ///  - handler: An asynchronous closure that is called when a notification with the specified name is posted. The closure receives the notification as its parameter.
  public func onNotification(
    named notificationName: Notification.Name,
    perform handler: @escaping @Sendable (Notification) async -> Void
  ) -> some View {
    self.modifier(
      OnNotificationModifier(
        notificationName: notificationName,
        handler: handler
      )
    )
  }

  /// Adds a handler for notifications with the specified name.
  /// - Parameters:
  ///  - notificationName: The name of the notifications to observe.
  ///  - handler: An asynchronous closure that is called when a notification with the specified name is posted. The closure does not receive any parameters.
  public func onNotification(
    named notificationName: Notification.Name,
    perform handler: @escaping @Sendable () async -> Void
  ) -> some View {
    self.modifier(
      OnNotificationModifier(
        notificationName: notificationName,
        handler: { _ in await handler() }
      )
    )
  }
}
