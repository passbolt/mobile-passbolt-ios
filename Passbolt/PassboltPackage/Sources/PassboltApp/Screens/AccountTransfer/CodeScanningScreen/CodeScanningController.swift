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

import AccountSetup
import FeatureScopes
import UIComponents

internal struct CodeScanningController {

  internal var progressPublisher: @MainActor () -> AnyPublisher<Double, Never>
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var presentHelp: @MainActor () -> Void
  internal var helpPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  // We expect this publisher to finish on process success and fail on process error
  internal var resultPresentationPublisher: @MainActor () -> AnyPublisher<Never, Error>
}

extension CodeScanningController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features = try features.branch(scope: AccountTransferScope.self)

    let accountTransfer: AccountImport = try features.instance()
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let helpPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let resultPresentationSubject: PassthroughSubject<Never, Error> = .init()

    accountTransfer
      .progressPublisher()
      .sink(
        receiveCompletion: { completion in
          guard case .failure(let error) = completion
          else { return }
          resultPresentationSubject.send(completion: .failure(error))
        },
        receiveValue: { progress in
          guard case .scanningFinished = progress
          else { return }
          resultPresentationSubject.send(completion: .finished)
        }
      )
      .store(in: cancellables)

    func progressPublisher() -> AnyPublisher<Double, Never> {
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
        .eraseToAnyPublisher()
    }

    func presentExitConfirmation() {
      exitConfirmationPresentationSubject.send(true)
    }

    func exitConfirmationPresentationPublisher() -> AnyPublisher<Bool, Never> {
      exitConfirmationPresentationSubject.eraseToAnyPublisher()
    }

    func presentHelp() {
      helpPresentationSubject.send(true)
    }

    func helpPresentationPublisher() -> AnyPublisher<Bool, Never> {
      helpPresentationSubject.eraseToAnyPublisher()
    }

    func resultPresentationPublisher() -> AnyPublisher<Never, Error> {
      resultPresentationSubject.eraseToAnyPublisher()
    }

    return Self(
      progressPublisher: progressPublisher,
      presentExitConfirmation: presentExitConfirmation,
      exitConfirmationPresentationPublisher: exitConfirmationPresentationPublisher,
      presentHelp: presentHelp,
      helpPresentationPublisher: helpPresentationPublisher,
      resultPresentationPublisher: resultPresentationPublisher
    )
  }
}
