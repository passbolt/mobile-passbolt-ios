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

import Foundation

final class CreateFolderScenario: UITestCase {
  override var initialAccounts: Array<MockAccount> {
    [
      .automation
    ]
  }

  override func beforeEachTestCase() {
    // in case this tests starts with already set up single account, we mark it as optional
    selectCollectionViewItem(identifier: "account.selection.collectionview", at: 0, required: false)
    typeTo("input", text: MockAccount.automation.username)
    tap("button.signin.passphrase")
    tap("biometrics.info.later.button", required: false, timeout: 2.0)
    tap("biometrics.setup.later.button", required: false, timeout: 2.0)
    tap("extension.setup.later.button", required: false, timeout: 2.0)
    tap("search.view.menu", timeout: 5.0)
    tap("foldersExplorer")
    tap("folder.explore.create.new")
    tap("resource.folders.add.folder")
  }

  func test_folderCannotBeCreated_withInvalidname() {
    waitForElementExist("folder.edit.form.button")
    tap("folder.edit.form.button")
    assertExists("form.textfield.error")
    assert("form.textfield.error", textMatches: "Folder name cannot be empty.")
    assertPresentsString(matching: "Form is not valid.")
  }

  func test_folderIsCreated_whenNameProvided() {
    waitForElementExist("form.textfield.text")
    typeTo("form.textfield.text", text: "Automation test folder")
    tap("folder.edit.form.button")
    assertNotExists("form.textfield.error")
  }

}
