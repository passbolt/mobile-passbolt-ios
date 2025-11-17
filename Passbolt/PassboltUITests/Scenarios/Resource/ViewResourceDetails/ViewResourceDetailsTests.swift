//
// Passbolt - Open source password manager for teams
// Copyright (c) 2024 Passbolt SA
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

import XCTest

final class ViewResourceDetailsTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    selectAllItemsFilter()
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_asAUserOnTheHomepageICanAccessTheResourcePageForWhichIHaveFullPermissionsForSimplePassword() throws {
    //      Given   I am on the homepage
    //      And     I have permission to view the password
    //      When    I click on a <resource>
    try type(text: "Simple Password", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //      Then    I see the resource display screen
    //      And I see an arrow on the top left corner to go back to the previous page
    assertExists("Back")
    //      And I see a “3 dots” icon on the top right corner
    assertExists("More")
    //      And I see the resource favicon or a default icon
    assertExists("KeepassIconSet/key")
    //      And I see the resource name
    assertPresentsString(matching: "Simple Password")
    //      And I see the “Website URL” list item with title, value and a copy icon
    assertExists("Main URI")
    assertPresentsString(matching: "https://cloud.passbolt.com/automate")
    assertExists("copy.button.Main URI")
    //      And I see the “Username” list item with title, value and a copy icon
    assertExists("Username")
    assertPresentsString(matching: "Automate")
    assertExists("copy.button.Username")
    //      And I see the “Password” list item with title, hidden value and a show icon
    assertExists("Password")
    assertExists("••••••••", inside: "text.encrypted.Password")
    assertExists("reveal.button.Password")
    //      And I see the “Description” list item with title, hidden value and a show icon
    assertExists("Description")
    assertPresentsString(matching: "Description is unencrypted this time")
    assertExists("copy.button.Description")
    //      And I see the "Metadata" subsection with title
    assertExists("Metadata")
    try swipeUp("Metadata")  // Next elements can be off-screen - make sure they are visible
    //      And I see "Tags" subsection
    assertExists("Tags")
    //      And I see "Location" subsection
    assertExists("Location")
    //      And I see "Shared with" subsection
    try swipeUp("Metadata")  // Next elements can be off-screen - make sure they are visible
    assertExists("Shared with")
    //
    //      Examples:
    //          | resource                    |
    //        >>| Simple password             |
    //          | Password with description   |
    //          | Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_asAUserOnTheHomepageICanAccessTheResourcePageForWhichIHaveFullPermissionsForPasswordWithDescription() throws
  {
    //      Given   I am on the homepage
    //      And     I have permission to view the password
    //      When    I click on a <resource>
    try type(text: "Password and description", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //      Then    I see the resource display screen
    //      And I see an arrow on the top left corner to go back to the previous page
    assertExists("Back")
    //      And I see a “3 dots” icon on the top right corner
    assertExists("More")
    //      And I see the resource favicon or a default icon
    assertExists("KeepassIconSet/key")
    //      And I see the resource name
    assertPresentsString(matching: "Password and description")
    //      And I see the “Website URL” list item with title, value and a copy icon
    assertExists("Main URI")
    assertPresentsString(matching: "https://passbolt.testrail.io/index.php?/cases/view/10599")
    assertExists("copy.button.Main URI")
    //      And I see the “Username” list item with title, value and a copy icon
    assertExists("Username")
    assertPresentsString(matching: "Automate")
    assertExists("copy.button.Username")
    //      And I see the “Password” list item with title, hidden value and a show icon
    assertExists("Password")
    assertExists("••••••••", inside: "text.encrypted.Password")
    assertExists("reveal.button.Password")
    //      And I see the “Note” list item with title, hidden value and a show icon
    assertExists("Note")
    assert("text.encrypted.note", textEqual: "••••••••")
    assertExists("reveal.button.note")
    try swipeUp("Note")  // Next elements can be off-screen - make sure they are visible
    //      And I see the "Metadata" subsection with title
    assertExists("Metadata")
    //      And I see "Tags" subsection
    assertExists("Tags")
    //      And I see "Location" subsection
    assertExists("Location")
    try swipeUp("Metadata")  // Next elements can be off-screen - make sure they are visible
    //      And I see "Shared with" subsection
    assertExists("Shared with")
    //
    //      Examples:
    //          | resource                    |
    //          | Simple password             |
    //        >>| Password with description   |
    //          | Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_asAUserOnTheHomepageICanAccessTheResourcePageForWhichIHaveFullPermissionsForPasswordDescriptionTOTP() throws
  {
    //      Given   I am on the homepage
    //      And     I have permission to view the password
    //      When    I click on a <resource>
    try type(text: "Password description totp", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //      Then    I see the resource display screen
    //      And I see an arrow on the top left corner to go back to the previous page
    assertExists("Back")
    //      And I see a “3 dots” icon on the top right corner
    assertExists("More")
    //      And I see the resource favicon or a default icon
    assertExists("KeepassIconSet/password_with_totp")
    //      And I see the resource name
    assertPresentsString(matching: "Password description totp", timeout: 5.0)
    //      And I see the “Website URL” list item with title, value and a copy icon
    assertExists("Main URI")
    assertPresentsString(matching: "https://passbolt.testrail.io/index.php?/cases/view/10599")
    assertExists("copy.button.Main URI")
    //      And I see the “Username” list item with title, value and a copy icon
    assertExists("Username")
    assertPresentsString(matching: "Automate")
    assertExists("copy.button.Username")
    //      And I see the “Password” list item with title, hidden value and a show icon
    assertExists("Password")
    assertExists("••••••••", inside: "text.encrypted.Password")
    assertExists("reveal.button.Password")
    try swipeUp("TOTP")  // Next elements can be off-screen - make sure they are visible
    //      And I see the “Note” list item with title, hidden value and a show icon
    assertExists("Note")
    assert("text.encrypted.note", textEqual: "••••••••")
    assertExists("reveal.button.note")
    //      And I see "Tags" subsection
    assertExists("Tags")
    //      And I see "Location" subsection
    assertExists("Location")
    //      And I see "Shared with" subsection
    assertExists("Shared with")
    //
    //      Examples:
    //          | resource                    |
    //          | Simple password             |
    //          | Password with description   |
    //        >>| Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2444
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanShowOrHideThePasswordForSimplePassword() throws {
    //      Given I am a mobile user on the "<resource>" view page
    //        And   I have permission to view the password
    try type(text: "Simple Password", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //        When  I click on the "show" icon in the "password" list item
    try tap("reveal.button.Password")
    //        And   I successfully authenticate using biometric or passphrase if required
    //        Then  I should see the password displayed
    assertPresentsString(matching: "BettyPassword")
    //        And   I should observe the "show" icon change its state
    assertExists("hide.button.Password")
    //
    //        When  I click on the "hide" icon
    try tap("hide.button.Password")
    //        Then  I should see the password hidden
    assertExists("••••••••", inside: "text.encrypted.Password")
    //
    //        Examples:
    //            | resource                    |
    //          >>| Simple password             |
    //            | Password with description   |
    //            | Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2444
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanShowOrHideThePasswordForPasswordWithDescription() throws {
    //      Given I am a mobile user on the "<resource>" view page
    //        And   I have permission to view the password
    try type(text: "Password and description", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //        When  I click on the "show" icon in the "password" list item
    try tap("reveal.button.Password")
    //        And   I successfully authenticate using biometric or passphrase if required
    //        Then  I should see the password displayed
    assertPresentsString(matching: "PassDess1234!@#$")
    //        And   I should observe the "show" icon change its state
    assertExists("hide.button.Password")
    //
    //        When  I click on the "hide" icon
    try tap("hide.button.Password")
    //        Then  I should see the password hidden
    assertExists("••••••••", inside: "text.encrypted.Password")
    //
    //        Examples:
    //            | resource                    |
    //            | Simple password             |
    //          >>| Password with description   |
    //            | Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2444
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanShowOrHideThePasswordForPasswordWithDescriptionTOTP() throws {
    //      Given I am a mobile user on the "<resource>" view page
    //        And   I have permission to view the password
    try type(text: "Password description totp", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //        When  I click on the "show" icon in the "password" list item
    try tap("reveal.button.Password")
    //        And   I successfully authenticate using biometric or passphrase if required
    //        Then  I should see the password displayed
    assertPresentsString(matching: "PassDessTOTP1234!@#$")
    //        And   I should observe the "show" icon change its state
    assertExists("hide.button.Password")
    //
    //        When  I click on the "hide" icon
    try tap("hide.button.Password")
    //        Then  I should see the password hidden
    assertExists("••••••••", inside: "text.encrypted.Password")
    //
    //        Examples:
    //            | resource                    |
    //            | Simple password             |
    //            | Password with description   |
    //          >>| Password description totp   |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2447
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanShowOrHideResourceDescriptionForPasswordWithDescription()
    throws
  {
    //        Given I am a mobile user on the <resource> display screen
    try type(text: "Password and description", to: "search.view.input", timeout: 10.0)
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //        When  I click on the show icon in the “Description” item list
    try tap("reveal.button.note")
    //        And   I successfully authenticate (if needed)
    //        Then  I should see a spinner in place of the eye icon
    //        And   I should see the description
    assertExists("Description is encrypted")
    //        And   I should see a hide icon
    assertExists("hide.button.note")
    //
    //        When  I click on the hide icon
    try tap("hide.button.note")
    //        Then  I should see the description hidden
    assert("text.encrypted.note", textEqual: "••••••••")
    //
    //        Examples:
    //            | resource |
    //          >>| Password with description   |
    //            | Password description totp |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2447
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanShowOrHideResourceDescriptionForPasswordWithDescriptionTOTP()
    throws
  {
    //        Given I am a mobile user on the <resource> display screen
    try type(text: "Password description totp", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try swipeUp("TOTP")  // Make sure the Note field is visible
    //        When  I click on the show icon in the “Description” item list
    try tap("reveal.button.note")
    //        And   I successfully authenticate (if needed)
    //        Then  I should see a spinner in place of the eye icon
    //        And   I should see the description
    assertExists("Description encrypted - password-description-totp")
    //        And   I should see a hide icon
    assertExists("hide.button.note")
    //
    //        When  I click on the hide icon
    try tap("hide.button.note")
    //        Then  I should see the description hidden
    assert("text.encrypted.note", textEqual: "••••••••")
    //
    //        Examples:
    //            | resource |
    //            | Password with description |
    //          >>| Password description totp |
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9454
  func test_AsALoggedInMobileUserOnTheResourceDisplayICanSeeSimplePasswordDescription() throws {
    //        Given I am a mobile user on the "Simple password" display screen
    try type(text: "Simple Password", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    //        And   I have the description filled
    //        When  I check the “Description” item list
    assertExists("Description")
    //        Then  I should see the description unhide
    assertPresentsString(matching: "Description is unencrypted this time")
    //        And   I should see a copy icon
    assertExists("copy.button.Description")
  }
}
