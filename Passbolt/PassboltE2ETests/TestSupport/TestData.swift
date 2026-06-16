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

internal struct ResourceTestData {

  internal let resourceName: String
  internal let mainURI: String
  internal let username: String
  internal let password: String
  internal let description: String
  internal let note: String?
  internal let iconIdentifier: String?

  internal init(
    resourceName: String,
    mainURI: String,
    username: String,
    password: String,
    description: String,
    note: String? = nil,
    iconIdentifier: String? = nil
  ) {
    self.resourceName = resourceName
    self.mainURI = mainURI
    self.username = username
    self.password = password
    self.description = description
    self.note = note
    self.iconIdentifier = iconIdentifier
  }
}

extension ResourceTestData {

  internal static let simplePasswordV4: Self = .init(
    resourceName: "Simple password - v4",
    mainURI: "https://www.passbolt.com",
    username: "BettyAutomate",
    password: "TestPassword123!",
    description: "This test description is unencrypted this time",
    iconIdentifier: "KeepassIconSet/key"
  )

  internal static let passwordWithDescriptionV4: Self = .init(
    resourceName: "Password with description - v4",
    mainURI: "https://www.passbolt.com",
    username: "BettyAutomate",
    password: "TestPassword123!",
    description: "This test description is unencrypted this time",
    iconIdentifier: "KeepassIconSet/key"
  )

  internal static let simplePasswordDeprecated: Self = .init(
    resourceName: "Simple Password (Deprecated)",
    mainURI: "https://www.passbolt.com",
    username: "BettyAutomate",
    password: "TestPassword123!",
    description: "This test description is unencrypted this time"
  )

  internal static let defaultResourceType: Self = .init(
    resourceName: "Default resource type",
    mainURI: "https://www.passbolt.com",
    username: "BettyAutomate",
    password: "TestPassword123!",
    description: "This test description is unencrypted this time"
  )

  internal static let passwordDescriptonNote: Self = .init(
    resourceName: "Default resource type",
    mainURI: "https://www.passbolt.com",
    username: "BettyAutomate",
    password: "TestPassword123!",
    description: "This test description is unencrypted this time",
    note: "This is a Note which is secret"
  )

  internal static let passwordWithDescription: Self = .init(
    resourceName: "Password and description",
    mainURI: "https://passbolt.testrail.io/index.php?/cases/view/10599",
    username: "Automate",
    password: "TestPassword123!",
    description: "Description is encrypted",
    note: "Description is encrypted",
    iconIdentifier: "KeepassIconSet/key"
  )

  internal static let passwordDescriptionTOTP: Self = .init(
    resourceName: "Password description totp",
    mainURI: "https://passbolt.testrail.io/index.php?/cases/view/10599",
    username: "Automate",
    password: "TestPassword123!",
    description: "Description encrypted - password-description-totp",
    note: "Description encrypted - password-description-totp",
    iconIdentifier: "KeepassIconSet/password_with_totp"
  )

  internal static let testResource: Self = .init(
    resourceName: "TestiOS",
    mainURI: "UrlTestOniOS",
    username: "UsernameTestOniOS",
    password: "PasswordTestOniOS",
    description: ""
  )

  internal static let editableResource: Self = .init(
    resourceName: "ResourcesEditionTestOniOS",
    mainURI: "TestURL",
    username: "TestUsername",
    password: "",
    description: ""
  )
}

// MARK: - TOTPTestData

internal struct TOTPTestData {

  internal let resourceName: String
  internal let iconIdentifier: String

  internal init(
    resourceName: String,
    iconIdentifier: String
  ) {
    self.resourceName = resourceName
    self.iconIdentifier = iconIdentifier
  }
}

extension TOTPTestData {

  internal static let standaloneTOTP: Self = .init(
    resourceName: "A Standalone TOTP",
    iconIdentifier: "KeepassIconSet/totp"
  )
}

// MARK: - FolderTestData

internal struct FolderTestData {

  internal let folderName: String
  internal let folderDescription: String

  internal init(
    folderName: String,
    folderDescription: String = ""
  ) {
    self.folderName = folderName
    self.folderDescription = folderDescription
  }
}

extension FolderTestData {

  internal static let emptyFolder: Self = .init(
    folderName: "Empty Folder",
    folderDescription: "Empty folder for testing"
  )

  internal static let automatedTestsFolder: Self = .init(
    folderName: "Automated tests folder iOS"
  )
}
