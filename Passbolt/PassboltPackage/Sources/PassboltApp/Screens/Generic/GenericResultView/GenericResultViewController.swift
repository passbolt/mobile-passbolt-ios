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

internal final class GenericResultViewController: ViewController {

  internal struct ViewState: Equatable {
    internal let icon: ImageNameConstant
    internal let title: DisplayableString
    internal let message: DisplayableString?
    internal let buttonTitle: DisplayableString
  }

  internal struct Context {

    internal let icon: ImageNameConstant
    internal let title: DisplayableString
    internal let message: DisplayableString?
    internal let buttonTitle: DisplayableString
    internal let buttonAction: () async throws -> Void

    internal init(
      icon: ImageNameConstant,
      title: DisplayableString,
      message: DisplayableString? = .none,
      buttonTitle: DisplayableString,
      buttonAction: @escaping () async throws -> Void
    ) {
      self.icon = icon
      self.title = title
      self.message = message
      self.buttonTitle = buttonTitle
      self.buttonAction = buttonAction
    }

    static internal func `for`(
      error: Error,
      confirmation: @escaping @Sendable () async throws -> Void
    ) -> Self {
      .init(
        icon: .failureMark,
        title: "generic.error",
        message: error.asTheError().displayableMessage,
        buttonTitle: "generic.try.again",
        buttonAction: confirmation
      )
    }
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let action: () async throws -> Void

  internal init(context: Context, features: Features) throws {
    self.action = context.buttonAction
    self.viewState = .init(
      initial: .init(
        icon: context.icon,
        title: context.title,
        message: context.message,
        buttonTitle: context.buttonTitle
      )
    )
  }

  internal func handleButtonTap() async throws {
    try await action()
  }
}
