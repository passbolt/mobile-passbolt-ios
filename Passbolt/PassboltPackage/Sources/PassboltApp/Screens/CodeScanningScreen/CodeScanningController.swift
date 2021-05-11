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

import UIComponents

internal struct CodeScanningController {
  
  internal var progressPublisher: () -> AnyPublisher<Double, Never>
  internal var updateProgress: (UInt, UInt) -> Void
  internal var presentExitConfirmation: () -> Void
  internal var dismissExitConfirmation: () -> Void
  internal var exitConfirmationPresentationPublisher: () -> AnyPublisher<Bool, Never>
  internal var presentHelp: () -> Void
  internal var dismissHelp: () -> Void
  internal var helpPresentationPublisher: () -> AnyPublisher<Bool, Never>
}

extension CodeScanningController: UIController {
  
  internal struct State {
    
    internal var steps: UInt = 20 // starting with some value that should be higher than most typical processes
    // to allow progress rise when actually completing first step
    internal var completedSteps: UInt = 1 // starting with least value above zero to render any progress
    internal var progress: Double { Double(completedSteps) / Double(steps) }
  }
  
  internal typealias Context = Void
  
  internal static func instance(
    in context: Context,
    with features: FeatureFactory
  ) -> Self {
    let state: CurrentValueSubject<State, Never> = .init(State())
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    let helpPresentationSubject: PassthroughSubject<Bool, Never> = .init()
    #warning("TODO: [PAS-39] Use code reader (camera) component")
    return Self(
      progressPublisher: state
        .map(\.progress)
        .removeDuplicates()
        .eraseToAnyPublisher,
      updateProgress: { steps, completed in
        var stateValue: State = state.value
        stateValue.steps = steps
        stateValue.completedSteps = completed
        state.value = stateValue
      },
      presentExitConfirmation: { exitConfirmationPresentationSubject.send(true) },
      dismissExitConfirmation: { exitConfirmationPresentationSubject.send(false) },
      exitConfirmationPresentationPublisher: exitConfirmationPresentationSubject.eraseToAnyPublisher,
      presentHelp: { helpPresentationSubject.send(true) },
      dismissHelp: { helpPresentationSubject.send(false) },
      helpPresentationPublisher: helpPresentationSubject.eraseToAnyPublisher
    )
  }
}

extension CodeScanningController {
  
  internal func updateProgress(steps: UInt, completed: UInt) {
    updateProgress(steps, completed)
  }
}
