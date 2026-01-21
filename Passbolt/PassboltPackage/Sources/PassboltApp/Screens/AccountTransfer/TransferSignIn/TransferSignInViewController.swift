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
  private var cancellables: Set<AnyCancellable> = .init()

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

    accountTransfer.accountDetailsPublisher()
      .map { details -> AccountImport.AccountDetails? in details }
      .collectErrorLog()
      .replaceError(with: nil)
      .filterMapOptional()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] details in
        self?.viewState.update(\.account, to: details)
      }
      .store(in: &cancellables)

    accountTransfer
      .avatarPublisher()
      .map { data -> Data? in data }
      .collectErrorLog()
      .replaceError(with: nil)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] avatarData in
        self?.viewState.update(\.avatarData, to: avatarData)
      }
      .store(in: &cancellables)

    accountTransfer
      .progressPublisher()
      .ignoreOutput()
      .eraseToAnyPublisher()
      .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
          break
        case .failure(_ as Cancelled):
          Task { [weak self] in
            await self?.cancelTransfer()
          }
        case .failure(let error):
          Task { [weak self] in
            try await self?.navigationToResult
              .perform(
                context: .for(
                  error: error,
                  confirmation: { [weak self] in
                    await self?.cancelTransfer()
                  }
                )
              )
          }
        }
      })
      .store(in: &cancellables)
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
            perform: cancelTransfer
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
    let passphrase: Passphrase = .init(rawValue: validatedPassphrase.value)
    accountTransfer
      .completeTransfer(passphrase)
      .ignoreOutput()
      .eraseToAnyPublisher()
      .receive(on: DispatchQueue.main)
      .handleErrors { [weak self] error in
        switch error {
        case is Cancelled:
          return /* NOP */

        case let serverError as ServerConnectionIssue:
          self?.viewState.update(\.alert, to: .serverErrorAlert(with: serverError.serverURL))

        case let serverError as ServerResponseTimeout:
          self?.viewState.update(\.alert, to: .serverErrorAlert(with: serverError.serverURL))

        case is SessionMFAAuthorizationRequired:
          return  // ignore, handled by window controller

        case _:
          SnackBarMessageEvent.send(.error(error))
        }
      }
      .sink(receiveCompletion: { _ in
        withAnimation {
          self.viewState.update(\.isLoading, to: false)
        }

      })
      .store(in: &self.cancellables)
  }

  internal func cancelTransfer() async {
    accountTransfer.cancelTransfer()
    await consumingErrors {
      try await self.navigationToResult.revert()
      try await self.navigationToSelf.revert()
    }
  }

  internal func presentHelpMenu() async {
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
