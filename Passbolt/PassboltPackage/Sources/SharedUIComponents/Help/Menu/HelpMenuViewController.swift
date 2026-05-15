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

import AccountSetup
import Display
import OSFeatures

public final class HelpMenuViewController: ViewController {

  public struct ViewState: Equatable, Sendable {
    var actions: Array<Action>
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  private let navigationToSelf: NavigationToHelpMenu
  private let transferFeatures: Features
  private let resolvedActions: Array<Action>

  public init(context: Array<Action>, features: Features) throws {
    let linkOpener: OSLinkOpener = features.instance()
    let navigationToSelf: NavigationToHelpMenu = try features.instance()
    self.navigationToSelf = navigationToSelf

    self.transferFeatures = try features.branch(scope: AccountTransferScope.self)
    let navigationToAccountKitPicker: NavigationToAccountKitPicker = try transferFeatures.instance()
    let accountKitImport: AccountKitImport = try transferFeatures.instance()
    let navigationToLogsViewer: NavigationToLogsViewer = try features.instance()
    self.resolvedActions =
      context
      + [
        .init(
          title: "help.menu.show.logs.action.title",
          icon: .bug,
          action: {
            try await navigationToLogsViewer.perform(context: .init(useCustomNavigationBar: true))
          }
        ),
        accountKitImport.isImportAccountKitAvailable()
          ? .init(
            title: "help.menu.show.import.account.kit.title",
            icon: .importFile,
            action: { @MainActor in
              try await navigationToSelf.revert()
              try await navigationToAccountKitPicker.perform()
            }
          )
          : nil,
        .init(
          title: "help.menu.show.web.help.action.title",
          icon: .open,
          action: {
            try await linkOpener
              .openURL("https://help.passbolt.com")
          }
        ),
      ]
      .compactMap { $0 }
    self.viewState = .init(
      initial: .init(
        actions: []
      )
    )
  }

  // Populate the menu with options async - otherwise it breaks height calculation on iOS 16
  @MainActor internal func activate() async {
    let actions: Array<Action> = self.resolvedActions
    self.viewState.update { state in
      state.actions = actions
    }
  }

  internal func closeMenu() async {
    await consumingErrors {
      try await self.navigationToSelf.revert()
    }
  }

  public struct Action: Equatable, Hashable, Sendable {

    internal let title: DisplayableString
    internal let icon: ImageNameConstant
    internal let action: @Sendable () async throws -> Void

    public init(
      title: DisplayableString,
      icon: ImageNameConstant,
      action: @Sendable @escaping () async throws -> Void
    ) {
      self.title = title
      self.icon = icon
      self.action = action
    }

    public static func == (
      lhs: HelpMenuViewController.Action,
      rhs: HelpMenuViewController.Action
    ) -> Bool {
      lhs.title == rhs.title && lhs.icon == rhs.icon
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.title)
      hasher.combine(self.icon)
    }
  }
}

extension ImageNameConstant: @retroactive @unchecked Sendable {

}
