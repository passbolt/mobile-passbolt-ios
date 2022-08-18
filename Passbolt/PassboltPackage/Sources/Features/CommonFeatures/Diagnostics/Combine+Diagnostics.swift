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

import CommonModels
import Environment

extension Publisher where Failure == TheErrorLegacy {

  public func collectErrorLog(
    withPrefix prefix: StaticString = "",
    using diagnostics: Diagnostics
  ) -> Publishers.HandleEvents<Self> {
    handleEvents(receiveCompletion: { completion in
      switch completion {
      case .finished, .failure(.canceled):
        break

      case let .failure(error):
        #if DEBUG
        diagnostics.debugLog("\(prefix)\(error.debugDescription)")
        #else
        if let theError: TheError = error.legacyBridge {
          theError
            .diagnosticMessages
            .forEach { message in
              diagnostics.diagnosticLog(message)
            }
        }
        else {
          diagnostics
            .diagnosticLog(
              "Error: %{public}s",
              variable: error.identifier.rawValue
            )
        }
        #endif
      }
    })
  }
}

extension Publisher {

  public func collectErrorLog(
    using diagnostics: Diagnostics
  ) -> Publishers.HandleEvents<Self> {
    self.handleEvents(
      receiveCompletion: { (completion: Subscribers.Completion<Self.Failure>) -> Void in
        switch completion {
        case .finished:
          break

        case let .failure(error)
        where error is Cancelled:
          break

        case let .failure(error)
        where error is CancellationError:
          break

        // TODO: remove after migrating to TheError
        case let .failure(error as TheErrorLegacy):
          guard error.identifier != .canceled
          else { return }
          #if DEBUG
          diagnostics.debugLog(error.debugDescription)
          #else
          if let theError: TheError = error.legacyBridge {
            theError
              .diagnosticMessages
              .forEach { message in
                diagnostics.diagnosticLog(message)
              }
          }
          else {
            diagnostics
              .diagnosticLog(
                "Error: %{public}s",
                variable: error.identifier.rawValue
              )
          }
          #endif
        case let .failure(error as TheError):
          #if DEBUG
          diagnostics.debugLog(error.debugDescription)
          #else
          error
            .diagnosticMessages
            .forEach { message in
              diagnostics.diagnosticLog(message)
            }
          #endif

        case let .failure(error as Unidentified):
          #if DEBUG
          diagnostics.debugLog("\(error)")
          #else
          error
            .asUnidentified()
            .diagnosticMessages
            .forEach { message in
              diagnostics.diagnosticLog(message)
            }
          diagnostics.diagnosticLog(
            "Error: %{public}",
            unsafeVariable: error.underlyingError.localizedDescription
          )
          #endif

        case let .failure(error):
          let unidentified: Unidentified = error.asUnidentified()
          #if DEBUG
          diagnostics.debugLog("\(unidentified)")
          #else
          unidentified
            .diagnosticMessages
            .forEach { message in
              diagnostics.diagnosticLog(message)
            }
          diagnostics.diagnosticLog(
            "Error: %{public}",
            unsafeVariable: unidentified.underlyingError.localizedDescription
          )
          #endif
        }
      })
  }
}

extension Publisher {

  public func collectValueLog(
    withPrefix prefix: StaticString = "Received:",
    using diagnostics: Diagnostics
  ) -> AnyPublisher<Output, Failure> {
    #if DEBUG
    handleEvents(receiveOutput: { output in
      diagnostics.debugLog("\(prefix)\(output)")
    })
    .eraseToAnyPublisher()
    #else
    eraseToAnyPublisher()
    #endif
  }
}

extension Publisher {

  public func collectCancelationLog(
    withPrefix prefix: StaticString = "Canceled",
    using diagnostics: Diagnostics
  ) -> AnyPublisher<Output, Failure> {
    #if DEBUG
    handleEvents(receiveCancel: {

      diagnostics.debugLog("\(prefix)")
    })
    .eraseToAnyPublisher()
    #else
    eraseToAnyPublisher()
    #endif
  }
}
