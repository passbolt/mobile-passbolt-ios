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

import Combine

#warning("TODO: remove file after migration to TheError")

extension Publisher where Failure == TheErrorLegacy {

  public func handleErrors(
    _ cases: (Set<TheErrorLegacy.ID>, handler: (TheErrorLegacy) -> Bool)...,
    diagnosticLog: @escaping (TheError) -> Void = { _ in },
    file: StaticString = #file,
    line: UInt = #line,
    column: UInt = #column,
    defaultHandler: @escaping (TheErrorLegacy) -> Void
  ) -> Publishers.HandleEvents<Self> {
    self.handleEvents(receiveCompletion: { completion in
      guard case let .failure(error) = completion
      else { return }

      let handled: Bool =
        cases
        .first { $0.0.contains(error.identifier) }
        .map { $0.handler }
        .map { $0(error) }
        ?? false

      if !handled {
        defaultHandler(error)
      }
      else {
        /* NOP */
      }
      diagnosticLog(
        error
          .asTheError()
          .recording("Handled at \(file)@\(line):\(column)", for: "HandlingLocation")
      )
    })
  }
}

extension Publisher {

  public func mapErrorsToLegacy() -> Publishers.MapError<Self, TheErrorLegacy> {
    self.mapError { (error: Error) -> TheErrorLegacy in
      if let theError: TheError = error as? TheError {
        return theError.asLegacy
      }
      else if let legacyError: TheErrorLegacy = error as? TheErrorLegacy {
        return legacyError
      }
      else {
        return error.asUnidentified().asLegacy
      }
    }
  }
}
