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

import Display

internal struct NoticeDrawerViewModel: Equatable, Identifiable, Sendable {

  internal let id: IID
  internal let title: DisplayableString
  /// Template image displayed above the message.
  internal let icon: ImageNameConstant?
  /// Message paragraphs, rendered in order. Inline markdown (`**bold**`) applies.
  internal let paragraphs: Array<DisplayableString>
  /// Presented in the given order, from the top.
  internal let actions: Array<Action>

  internal init(
    id: IID = .init(),
    title: DisplayableString,
    icon: ImageNameConstant? = .none,
    paragraphs: Array<DisplayableString>,
    actions: Array<Action>
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.paragraphs = paragraphs
    self.actions = actions
  }

  internal static func == (
    _ lhs: NoticeDrawerViewModel,
    _ rhs: NoticeDrawerViewModel
  ) -> Bool {
    lhs.id == rhs.id
  }

  internal struct Action: Equatable, Identifiable, Sendable {

    internal let id: IID
    internal let title: DisplayableString
    internal let style: Style
    internal let perform: @MainActor () async -> Void

    internal init(
      id: IID = .init(),
      title: DisplayableString,
      style: Style,
      perform: @escaping @MainActor () async -> Void
    ) {
      self.id = id
      self.title = title
      self.style = style
      self.perform = perform
    }

    internal static func == (
      _ lhs: NoticeDrawerViewModel.Action,
      _ rhs: NoticeDrawerViewModel.Action
    ) -> Bool {
      lhs.id == rhs.id && lhs.title == rhs.title && lhs.style == rhs.style
    }

    internal enum Style: Equatable, Sendable {
      case primary
      case secondary
    }
  }
}
