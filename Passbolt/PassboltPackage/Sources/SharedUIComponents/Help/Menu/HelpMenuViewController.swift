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

  public struct ViewState: Equatable {
    let actions: Array<Action>
    var presentAccountKitPicker: Bool
  }

  public nonisolated let viewState: ViewStateSource<ViewState>
  private let navigationToSelf: NavigationToHelpMenu
  private let accountKitImport: AccountKitImport
  private let accountImportResultHandler: AccountImportResultHandler
  private var cancellables: Set<AnyCancellable> = []

  private let transferFeatures: Features

  public init(context: Array<Action>, features: Features) throws {
    let linkOpener: OSLinkOpener = features.instance()
    self.navigationToSelf = try features.instance()

    self.transferFeatures = try features.branch(scope: AccountTransferScope.self)
    self.accountImportResultHandler = try transferFeatures.instance()
    self.accountKitImport = try transferFeatures.instance()
    let navigationToLogsViewer: NavigationToLogsViewer = try features.instance()
    let click: PassthroughSubject<Void, Never> = .init()
    self.viewState = .init(
      initial: .init(
        actions: context
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
                action: {
                  click.send()
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
          .compactMap { $0 },
        presentAccountKitPicker: false
      )
    )
    click.sink(receiveValue: self.presentAccountKitPicker).store(in: &self.cancellables)
  }

  internal func closeMenu() async {
    await consumingErrors {
      try await self.navigationToSelf.revert()
    }
  }

  internal func presentAccountKitPicker() {
    self.viewState.update(\.presentAccountKitPicker, to: true)
  }

  internal func importAccountKit(from url: URL?) {
    self.viewState.update(\.presentAccountKitPicker, to: false)
    guard let url: URL = url else {
      return
    }
    Task {
      try await self.navigationToSelf.revert()
      do {
        let fileContents = try String(contentsOf: url, encoding: .utf8)

        let accountTransferData = try self.accountKitImport.importAccountKit(fileContents)
        try await self.accountImportResultHandler.handleImportResult(.success(accountTransferData))
      }
      catch {
        error.logged()
        try await self.accountImportResultHandler.handleImportResult(.failure(error))
      }
    }

  }

  public struct Action: Equatable, Hashable {

    internal let title: DisplayableString
    internal let icon: ImageNameConstant
    internal let action: () async throws -> Void

    public init(
      title: DisplayableString,
      icon: ImageNameConstant,
      action: @escaping () async throws -> Void
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
