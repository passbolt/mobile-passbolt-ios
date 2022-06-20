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

import Commons
import SwiftUI

public protocol AlertContent: Hashable {

  var title: DisplayableString { get }
  var message: DisplayableString { get }
}

extension View {

  @MainActor public func alert<Content, ContentView>(
    presenting: Binding<Content?>,
    @ViewBuilder contentView: (Content) -> ContentView
  ) -> some View
  where Content: AlertContent, ContentView: View {
    if #available(iOS 15.0, *) {
      return self.alert(
        presenting.wrappedValue?.title.string() ?? "",
        isPresented: presenting.optionalSome(),
        presenting: presenting.wrappedValue,
        actions: contentView,
        message: { (content: Content) in
          Text(
            displayable: content.message
          )
        }
      )
    }
    else {
      fatalError()
    }
  }
}

public struct ConfirmationAlertMessage {

  public var title: DisplayableString
  public var message: DisplayableString
  public var destructive: Bool
  public var confirmAction: () -> Void
  public var confirmLabel: DisplayableString
  public var cancelLabel: DisplayableString

  public init(
    title: DisplayableString,
    message: DisplayableString,
    destructive: Bool,
    confirmAction: @escaping () -> Void,
    confirmLabel: DisplayableString,
    cancelLabel: DisplayableString = .localized(key: .cancel)
  ) {
    self.title = title
    self.message = message
    self.destructive = destructive
    self.confirmAction = confirmAction
    self.confirmLabel = confirmLabel
    self.cancelLabel = cancelLabel
  }
}

extension ConfirmationAlertMessage: AlertContent {

  public static func == (
    _ lhs: ConfirmationAlertMessage,
    _ rhs: ConfirmationAlertMessage
  ) -> Bool {
    lhs.title == rhs.title
      && lhs.message == rhs.message
      && lhs.destructive == rhs.destructive
      && lhs.confirmLabel == rhs.confirmLabel
      && lhs.cancelLabel == rhs.cancelLabel
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.title)
    hasher.combine(self.message)
    hasher.combine(self.destructive)
    hasher.combine(self.confirmLabel)
    hasher.combine(self.cancelLabel)
  }
}

extension View {

  @MainActor public func alert(
    presenting: Binding<ConfirmationAlertMessage?>
  ) -> some View {

    self.alert(presenting: presenting) { (confirmation: ConfirmationAlertMessage) in
      if #available(iOS 15.0, *) {
        Button(
          role: .cancel,
          action: { /* NOP */  },
          label: {
            Text(displayable: confirmation.cancelLabel)
          }
        )
        Button(
          role: confirmation.destructive
            ? .destructive
            : .none,
          action: confirmation.confirmAction,
          label: {
            Text(displayable: confirmation.confirmLabel)
          }
        )
      }
      else {
        fatalError()
      }
    }
  }
}
