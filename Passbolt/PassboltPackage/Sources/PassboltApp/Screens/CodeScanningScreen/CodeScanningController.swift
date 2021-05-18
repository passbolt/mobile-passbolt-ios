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
import UIComponents

internal struct CodeScanningController {
  
  internal var progressPublisher: () -> AnyPublisher<Double, Never>
  internal var presentExitConfirmation: () -> Void
  internal var dismissExitConfirmation: () -> Void
  internal var exitConfirmationPresentationPublisher: () -> AnyPublisher<Bool, Never>
  internal var presentHelp: () -> Void
  internal var helpPresentationPublisher: () -> AnyPublisher<Bool, Never>
  // We expect this publisher to emit value on process success and fail on process error
  internal var resultPresentationPublisher: () -> AnyPublisher<Void, TheError>
}

extension CodeScanningController: UIController {
  
  internal typealias Context = Void
  
  internal static func instance(
    in context: Context,
    with features: FeatureFactory
  ) -> Self {
    let accountTransfer: AccountTransfer = features.instance()
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let helpPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    
    return Self(
      progressPublisher: accountTransfer
        .scanningProgressPublisher()
        .compactMap { progress -> Double? in
          switch progress {
          case .configuration:
            return 1 / 20 // some initial value, greater than zero but not too small
            
          // swiftlint:disable:next explicit_type_interface
          case let .progress(value):
            return value
            
          case .finished:
            return 1 // finished aka 100%
          }
        }
        .replaceError(with: 1) // we break the process on error so it is kind of 100%
        .removeDuplicates()
        .eraseToAnyPublisher,
      presentExitConfirmation: { exitConfirmationPresentationSubject.send(true) },
      dismissExitConfirmation: { exitConfirmationPresentationSubject.send(false) },
      exitConfirmationPresentationPublisher: exitConfirmationPresentationSubject.eraseToAnyPublisher,
      presentHelp: { helpPresentationSubject.send(true) },
      helpPresentationPublisher: helpPresentationSubject.eraseToAnyPublisher,
      resultPresentationPublisher: accountTransfer
        .scanningProgressPublisher()
        .compactMap { progress -> Void? in
          switch progress {
          case .configuration, .progress:
            return nil
            
          case .finished:
            return Void()
          }
        }
        .eraseToAnyPublisher
    )
  }
}
