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

@MainActor
final internal class ViewResourceDetailsLayoutTests: UITestCase {

  // MARK: - #2443 Resource Details Layout

  /// https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_resourceDetailsLayout_simplePassword() async throws {
    let resource: ResourceTestData = .simplePasswordV4
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Group("Verify header") {
          Verify(screen.backButton.exists, "Back button")
          Verify(screen.moreButton.exists, "More button")
          Verify(screen.resourceIcon(identifier: resource.iconIdentifier!).exists, "Resource icon")
          Verify(application.staticTexts[resource.resourceName].exists, "Resource name")
        }
        Group("Verify fields") {
          Verify(screen.mainURILabel.exists, "Main URI label")
          Verify(application.staticTexts[resource.mainURI].exists, "Main URI value")
          Verify(screen.copyURIButton.exists, "Copy URI button")
          Verify(screen.usernameLabel.exists, "Username label")
          Verify(application.staticTexts[resource.username].exists, "Username value")
          Verify(screen.copyUsernameButton.exists, "Copy username button")
          Verify(screen.passwordLabel.exists, "Password label")
          Verify(screen.encryptedPasswordValue.label == "••••••••", "Password hidden")
          Verify(screen.revealPasswordButton.exists, "Reveal password button")
        }
        Group("Verify description") {
          Verify(screen.descriptionLabel.exists, "Description label")
          Verify(application.staticTexts[resource.description].exists, "Description value")
          Verify(screen.copyDescriptionButton.exists, "Copy description button")
        }
        Group("Verify sections") {
          Verify(screen.metadataSection.exists, "Metadata section")
          ScrollDown()
          Verify(screen.tagsSection.exists, "Tags section")
          Verify(screen.locationSection.exists, "Location section")
          ScrollDown()
          Verify(screen.sharedWithSection.exists, "Shared with section")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_resourceDetailsLayout_passwordWithDescription() async throws {
    let resource: ResourceTestData = .passwordWithDescription
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Group("Verify header") {
          Verify(screen.backButton.exists, "Back button")
          Verify(screen.moreButton.exists, "More button")
          Verify(screen.resourceIcon(identifier: resource.iconIdentifier!).exists, "Resource icon")
          Verify(application.staticTexts[resource.resourceName].exists, "Resource name")
        }
        Group("Verify fields") {
          Verify(screen.mainURILabel.exists, "Main URI label")
          Verify(application.staticTexts[resource.mainURI].exists, "Main URI value")
          Verify(screen.copyURIButton.exists, "Copy URI button")
          Verify(screen.usernameLabel.exists, "Username label")
          Verify(application.staticTexts[resource.username].exists, "Username value")
          Verify(screen.copyUsernameButton.exists, "Copy username button")
          Verify(screen.passwordLabel.exists, "Password label")
          Verify(screen.encryptedPasswordValue.label == "••••••••", "Password hidden")
          Verify(screen.revealPasswordButton.exists, "Reveal password button")
        }
        Group("Verify note") {
          Verify(screen.noteLabel.exists, "Note label")
          Verify(screen.encryptedNoteValue.label.starts(with: "Never gonna give you up"), "Note hidden")
          Verify(screen.revealNoteButton.exists, "Reveal note button")
        }
        Group("Verify sections") {
          ScrollDown()
          Verify(screen.metadataSection.exists, "Metadata section")
          Verify(screen.tagsSection.exists, "Tags section")
          Verify(screen.locationSection.exists, "Location section")
          ScrollDown()
          Verify(screen.sharedWithSection.exists, "Shared with section")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2443
  func test_resourceDetailsLayout_passwordDescriptionTOTP() async throws {
    let resource: ResourceTestData = .passwordDescriptionTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Group("Verify header") {
          Verify(screen.backButton.exists, "Back button")
          Verify(screen.moreButton.exists, "More button")
          Verify(screen.resourceIcon(identifier: resource.iconIdentifier!).exists, "Resource icon")
          Verify(application.staticTexts[resource.resourceName].exists, "Resource name")
        }
        Group("Verify fields") {
          Verify(screen.mainURILabel.exists, "Main URI label")
          Verify(application.staticTexts[resource.mainURI].exists, "Main URI value")
          Verify(screen.copyURIButton.exists, "Copy URI button")
          Verify(screen.usernameLabel.exists, "Username label")
          Verify(application.staticTexts[resource.username].exists, "Username value")
          Verify(screen.copyUsernameButton.exists, "Copy username button")
          Verify(screen.passwordLabel.exists, "Password label")
          Verify(screen.encryptedPasswordValue.label == "••••••••", "Password hidden")
          Verify(screen.revealPasswordButton.exists, "Reveal password button")
        }
        Group("Verify note and sections") {
          ScrollDown()
          Verify(screen.noteLabel.exists, "Note label")
          Verify(screen.encryptedNoteValue.label.starts(with: "Never gonna give you up"), "Note hidden")
          Verify(screen.revealNoteButton.exists, "Reveal note button")
          Verify(screen.tagsSection.exists, "Tags section")
          Verify(screen.locationSection.exists, "Location section")
          Verify(screen.sharedWithSection.exists, "Shared with section")
        }
      }
    }
  }

  // MARK: - #2447 Description Reveal/Hide

  /// https://passbolt.testrail.io/index.php?/cases/view/2447
  func test_canRevealAndHideDescription_passwordWithDescription() async throws {
    let resource: ResourceTestData = .passwordWithDescription
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Group("Reveal description") {
          Tap(screen.revealNoteButton, "Reveal note")
          WaitFor(application.staticTexts[resource.note!], timeout: .standardUI, "Note revealed")
          Verify(application.staticTexts[resource.note!].exists, "Description visible")
          Verify(screen.hideNoteButton.exists, "Hide button visible")
        }
        .repeat(maxIterations: 3)

        Group("Hide description") {
          Tap(screen.hideNoteButton, "Hide note")
          Verify(screen.encryptedNoteValue.label.starts(with: "Never gonna give you up"), "Note hidden")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2447
  func test_canRevealAndHideDescription_passwordDescriptionTOTP() async throws {
    let resource: ResourceTestData = .passwordDescriptionTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        ScrollDown()

        Group("Reveal description") {
          Tap(screen.revealNoteButton, "Reveal note")
          WaitFor(application.staticTexts[resource.note!], timeout: .standardUI, "Note revealed")
          Verify(application.staticTexts[resource.note!].exists, "Description visible")
          Verify(screen.hideNoteButton.exists, "Hide button visible")
        }
        .repeat(maxIterations: 3)

        Group("Hide description") {
          Tap(screen.hideNoteButton, "Hide note")
          Verify(screen.encryptedNoteValue.label.starts(with: "Never gonna give you up"), "Note hidden")
        }
      }
    }
  }

  // MARK: - #9454 Simple Password Description

  /// https://passbolt.testrail.io/index.php?/cases/view/9454
  func test_simplePasswordDescriptionIsVisible() async throws {
    let resource: ResourceTestData = .simplePasswordV4
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectAllItemsFilter()
      OpenResourceDetails(resourceName: resource.resourceName)
      On(ResourceDetailsScreen.self) { screen in
        Verify(screen.descriptionLabel.exists, "Description label")
        Verify(application.staticTexts[resource.description].exists, "Description value")
        Verify(screen.copyDescriptionButton.exists, "Copy description button")
      }
    }
  }
}
