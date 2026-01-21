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

internal final class CodeScanningViewController: ViewController {

  internal struct ViewState: Equatable {
    internal var progress: Double = 0.0
    internal var alert: AlertViewModel? = .none
  }

  internal nonisolated let viewState: ViewStateSource<ViewState> = .init(initial: .init())

  private var cancellables: Set<AnyCancellable> = .init()
  private let accountTransfer: AccountImport
  private let navigationToSelf: NavigationToCodeScanning
  private let navigationToHelp: NavigationToHelpMenu
  private let navigationToResult: NavigationToGenericResult
  private let navigationToSignIn: NavigationToTransferSignIn
  private let navigationToAccountImportInfo: NavigationToAccountImportInfo
  private let features: Features

  internal init(context: (), features: Features) throws {
    let features = try features.branch(scope: AccountTransferScope.self)
    self.navigationToSelf = try features.instance()
    self.navigationToHelp = try features.instance()
    self.navigationToResult = try features.instance()

    self.navigationToAccountImportInfo = try features.instance()

    self.navigationToSignIn = try features.instance()
    accountTransfer = try features.instance()
    self.features = features
    accountTransfer
      .progressPublisher()
      .compactMap { progress -> Double? in
        switch progress {
        case .configuration:
          return 0  // initial value

        case .scanningProgress(let value):
          return value

        case .scanningFinished:
          return 1  // finished aka 100%
        }
      }
      .replaceError(with: 1)  // we break the process on error so it is kind of 100%
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink(
        receiveValue: { [weak self] progress in
          self?.viewState.update(\.progress, to: progress)
        }
      )
      .store(in: &self.cancellables)

    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { [weak self] completetion in
          guard case .failure(let error) = completetion
          else { return }
          self?.handle(result: .failure(error))
        },
        receiveValue: { [weak self] progress in
          guard case .scanningFinished = progress
          else { return }
          self?.handle(result: .success(()))
        }
      )
      .store(in: &self.cancellables)
  }

  private func handle(result: Result<Void, Error>) {
    switch result {
    case .success:
      Task {
        try await navigationToResult.perform(
          context: .init(
            icon: .successMark,
            title: "transfer.account.result.success.title",
            message: "",
            buttonTitle: .localized(key: .continue),
            buttonAction: { [weak self] in
              try await self?.navigationToSignIn.perform()
            }
          )
        )
      }
    case .failure(let error) where error is Cancelled:
      Task {
        try await self.navigationToSelf.revert()
      }
    case .failure(let error) where error is AccountDuplicate || error is AccountKitAccountAlreadyExist:
      Task {
        try await navigationToResult.perform(
          context: .init(
            icon: .duplicateMark,
            title: "transfer.account.result.already.linked.title",
            message: "",
            buttonTitle: .localized(key: .continue),
            buttonAction: { [weak self] in
              try await self?.navigationToSelf.revert()
            }
          )
        )
      }
    case .failure(let error):
      Task {
        try await navigationToResult.perform(
          context: .init(
            icon: .failureMark,
            title: "geenric.error",
            message: error.asTheError().displayableMessage,
            buttonTitle: "generic.try.again",
            buttonAction: { [weak self] in
              try await self?.navigationToAccountImportInfo.revert()
            }
          )
        )
      }
    }
  }

  internal func showHelp() async {
    await consumingErrors {
      try await navigationToHelp.perform(
        context: [
          .init(
            title: "code.scanning.help.menu.button.title",
            icon: .camera,
            action: { [weak self] in await self?.showQRCodeHelp() }
          )
        ]
      )
    }
  }

  private func showQRCodeHelp() async {
    await consumingErrors {
      try await navigationToHelp.revert()
    }
    self.viewState.update(
      \.alert,
      to: .init(
        title: "code.scanning.help.title",
        message: "code.scanning.help.message",
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
    )
  }

  internal func backButtonTapped() async {
    self.viewState.update(
      \.alert,
      to: .init(
        title: "transfer.account.exit.confirmation.title",
        message: "transfer.account.exit.confirmation.message",
        actions: [
          .cancel(
            id: .init(),
            title: .localized(key: .cancel)
          ),
          .destructive(
            id: .init(),
            title: "transfer.account.import.exit.confirmation.confirm.button.title",
            perform: { [weak self] in
              await self?.cancelImport()
            }
          ),
        ]
      )
    )
  }

  internal func cancelImport() async {
    await consumingErrors {
      try await navigationToAccountImportInfo.revert()
      accountTransfer.cancelTransfer()
    }
  }

  internal func handleCodeScannerAlert(_ alert: AlertViewModel) {
    self.viewState.update(\.alert, to: alert)
  }

  internal func processPayload(_ string: String) -> AnyPublisher<Never, Error> {
    self.accountTransfer.processPayload(string)
  }
}
