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

internal final class AccountKitPickerViewController: ViewController {

  private let navigationToSelf: NavigationToAccountKitPicker
  private let accountKitImport: AccountKitImport
  private let accountImportResultHandler: AccountImportResultHandler

  internal init(context: (), features: Features) throws {
    self.navigationToSelf = try features.instance()
    self.accountKitImport = try features.instance()
    self.accountImportResultHandler = try features.instance()
  }

  internal func onAccountKitSelected(_ url: URL?) {
    Task {
      await consumingErrors { [weak self] in
        try await self?.navigationToSelf.revert()
        guard let url: URL = url else {
          return
        }
        try await self?.importAccountKit(from: url)
      }
    }
  }

  private func importAccountKit(from url: URL) async throws {
    do {
      let fileContents: String = try .init(contentsOf: url, encoding: .utf8)
      let accountTransferData: AccountTransferData = try self.accountKitImport.importAccountKit(fileContents)
      try await self.accountImportResultHandler.handleImportResult(.success(accountTransferData))
    }
    catch {
      error.logged()
      try await self.accountImportResultHandler.handleImportResult(.failure(error))
    }
  }
}
