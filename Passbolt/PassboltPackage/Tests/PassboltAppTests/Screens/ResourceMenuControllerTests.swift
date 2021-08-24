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

@testable import Accounts
import Combine
import Features
@testable import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceMenuControllerTests: TestCase {

  var resources: Resources!
  var pasteboard: Pasteboard!
  var linkOpener: LinkOpener!

  override func setUp() {
    super.setUp()

    linkOpener = .placeholder
    pasteboard = .placeholder
    resources = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    resources = nil
  }

  func test_resourceDetailsPublisher_publishes_whenMenuIsPresented() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(linkOpener)
    features.use(pasteboard)
    features.use(resources)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    var result: ResourceDetailsController.ResourceDetails!

    controller.resourceDetailsPublisher()
      .sink(
        receiveCompletion: { _ in
          XCTFail("Unexpected completion")
        },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.id.rawValue, detailsViewResource.id.rawValue)
  }

  func test_availableActionsPublisher_publishesActionAvailable_whenMenuPresentedFromResourceList() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(linkOpener)
    features.use(pasteboard)
    features.use(resources)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceList)
    )
    let expectedActions: Array<ResourceMenuController.Action> = [
      .openURL, .copyURL, .copyPassword
    ]
    var result: Array<ResourceMenuController.Action>!

    controller.availableActionsPublisher()
      .sink { actions in
        result = actions
      }
      .store(in: cancellables)

    XCTAssertEqual(result, expectedActions)
  }

  func test_availableActionsPublisher_publishesActionAvailable_whenMenuPresentedFromResourceDetails() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(linkOpener)
    features.use(pasteboard)
    features.use(resources)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    let expectedActions: Array<ResourceMenuController.Action> = [
      .copyPassword
    ]
    var result: Array<ResourceMenuController.Action>!

    controller.availableActionsPublisher()
      .sink { actions in
        result = actions
      }
      .store(in: cancellables)

    XCTAssertEqual(result, expectedActions)
  }

  func test_resourceSecretPublisher_publishesSecret_andCopiesSecretToPasteboard_whenPerformActionCopyPassword_isCalled() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    resources.loadResourceSecret = always(
      Just(resourceSecret)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    var pasteboardContent: String? = nil
    pasteboard.put = { string in
      pasteboardContent = string
    }
    features.use(pasteboard)
    features.use(linkOpener)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    var result: String!

    controller.resourceSecretPublisher()
      .sink(
        receiveCompletion: { _ in
          XCTFail("Unexpected completion")
        },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    controller.performAction(.copyPassword)

    XCTAssertEqual(result, resourceSecret.password)
    XCTAssertEqual(pasteboardContent, resourceSecret.password)
  }

  func test_copyURLPublisher_andCopiesURLPasteboard_whenPerformActionCopyURL_isCalled() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)

    var pasteboardContent: String? = nil
    pasteboard.put = { string in
      pasteboardContent = string
    }
    features.use(pasteboard)
    features.use(linkOpener)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    var result: Void!

    controller.copyURLPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.performAction(.copyURL)

    XCTAssertNotNil(result)
    XCTAssertNotNil(pasteboardContent)
    XCTAssertEqual(pasteboardContent, detailsViewResource.url)
  }

  func test_openURLPublisher_publishesTrue_whenPerformActionOpenURL_isCalled_andSucceeds() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(pasteboard)

    var openedLink: URL? = nil
    linkOpener.openLink = { url in
      openedLink = url
      return Just(true).eraseToAnyPublisher()
    }
    features.use(linkOpener)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    var result: Bool!

    controller.openURLPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.performAction(.openURL)

    XCTAssertEqual(result, true)
    XCTAssertEqual(openedLink?.absoluteString, detailsViewResource.url)
  }

  func test_openURLPublisher_publishesFalse_whenPerformActionOpenURL_isCalled_andFails() {
    resources.resourceDetailsPublisher = always(
      Just(detailsViewResource)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(resources)
    features.use(pasteboard)

    linkOpener.openLink = { _ in
      Just(false).eraseToAnyPublisher()
    }
    features.use(linkOpener)

    let controller: ResourceMenuController = testInstance(
      context: (id: detailsViewResource.id, source: .resourceDetails)
    )
    var result: Bool!

    controller.openURLPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.performAction(.openURL)

    XCTAssertEqual(result, false)
  }
}

private let detailsViewResource: DetailsViewResource = .init(
  id: .init(rawValue: "1"),
  permission: .owner,
  name: "Passphrase",
  url: "https://passbolt.com",
  username: "passbolt@passbolt.com",
  description: "Passbolt",
  fields: [
    .string(name: "username", required: true, encrypted: false, maxLength: nil),
    .string(name: "password", required: true, encrypted: true, maxLength: nil),
    .string(name: "uri", required: true, encrypted: false, maxLength: nil),
    .string(name: "description", required: true, encrypted: false, maxLength: nil)
  ])

private let resourceSecret: ResourceSecret = .from(
  decrypted: #"["password" : "passbolt"]"#,
  using: .init()
)!

