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
import SharedUIComponents

internal final class TransferSignInViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var account: AccountImport.AccountDetails?
    internal var avatarData: Data?
    internal var passphrase: Validated<String> = .valid("")
    internal var isLoading: Bool = false
    internal var alert: AlertViewModel?
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  private var updatesTask: Task<Void, Never>?

  private let navigationToHelpMenu: NavigationToHelpMenu
  private let navigationToSelf: NavigationToTransferSignIn
  private let navigationToResult: NavigationToGenericResult
  private let accountTransfer: AccountImport

  internal init(context: (), features: Features) throws {
    self.navigationToHelpMenu = try features.instance()
    self.navigationToSelf = try features.instance()
    self.navigationToResult = try features.instance()
    self.accountTransfer = try features.instance()

    self.viewState = .init(
      initial: .init()
    )

    // Set initial state from current values
    let initialDetails = accountTransfer.accountDetails()
    let initialAvatar = accountTransfer.avatar()
    if let details = initialDetails {
      viewState.update(\.account, to: details)
    }
    if let avatar = initialAvatar {
      viewState.update(\.avatarData, to: avatar)
    }

    // Start listening for updates
    self.updatesTask = Task { [weak self, accountTransfer] in
      guard let self else { return }
      for await _ in accountTransfer.updates {
        let details = accountTransfer.accountDetails()
        let avatar = accountTransfer.avatar()
        await MainActor.run {
          self.viewState.update(\.account, to: details)
          self.viewState.update(\.avatarData, to: avatar)
        }
      }
    }
  }

  deinit {
    updatesTask?.cancel()
  }

  internal func backTapped() {
    viewState.update(
      \.alert,
      to: .init(
        title: "transfer.account.exit.confirmation.title",
        message: "transfer.account.exit.confirmation.message",
        actions: [
          .cancel(
            id: .init(),
            title: "transfer.account.import.exit.confirmation.cancel.button.title"
          ),
          .destructive(
            id: .init(),
            title: "transfer.account.exit.confirmation.confirm.button.title",
            perform: { [weak self] in await self?.cancelTransfer() }
          ),
        ]
      )
    )
  }

  internal func completeTransfer() async {
    let validatedPassphrase: Validated<String> = await self.viewState.current.passphrase
    guard validatedPassphrase.isValid
    else { return }
    withAnimation {
      viewState.update(\.isLoading, to: true)
    }
    defer {
      withAnimation {
        viewState.update(\.isLoading, to: false)
      }
    }
    let passphrase: Passphrase = .init(rawValue: validatedPassphrase.value)
    do {
      try await accountTransfer.completeTransfer(passphrase)
    }
    catch is Cancelled {
      return
    }
    catch let serverError as ServerConnectionIssue {
      viewState.update(\.alert, to: .serverErrorAlert(with: serverError.serverURL))
    }
    catch let serverError as ServerResponseTimeout {
      viewState.update(\.alert, to: .serverErrorAlert(with: serverError.serverURL))
    }
    catch is SessionMFAAuthorizationRequired {
      return  // ignore, handled by window controller
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
  }

  internal func cancelTransfer() async {
    accountTransfer.cancelTransfer()
    await consumingErrors {
      try await self.navigationToResult.revert()
      try await self.navigationToSelf.revert()
    }
  }

  @Sendable internal func presentHelpMenu() async {
    await consumingErrors {
      try await self.navigationToHelpMenu.perform(context: .init())
    }
  }

  internal func forgotPassphraseTapped() {
    viewState.update(
      \.alert,
      to: .forgotPasswordAlert()
    )
  }
}

extension AlertViewModel {
  fileprivate static func forgotPasswordAlert() -> AlertViewModel {
    .init(
      title: "authorization.forgot.passphrase.alert.title",
      message: "authorization.forgot.passphrase.alert.message",
      actions: [
        .regular(
          id: .init(),
          title: .localized(key: .gotIt),
          perform: {
            /** no-op */
          }
        )
      ]
    )
  }
}
