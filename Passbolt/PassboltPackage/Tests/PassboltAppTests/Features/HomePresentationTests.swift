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

import Accounts
import FeatureScopes
import Features
import SessionData
import TestExtensions
import XCTest

@testable import Shared
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class HomePresentationTests: LoadableFeatureTestCase<HomePresentation>, @unchecked Sendable {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useHomePresentation()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
  }

  func test_currentPresentationModeUpdatable_hasDefault_initially() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.ownedResourcesList)
    )

    let feature: HomePresentation = try testedInstance()

    let result: HomePresentationMode? =
      try await feature
      .currentPresentationModeUpdatable().value

    XCTAssertEqual(result, .ownedResourcesList)
  }

  func test_currentPresentationModeUpdatable_fallsBackToPlainList_whenStoredModeUnavailable() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: SessionConfiguration.default
      )
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.foldersExplorer)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let result: HomePresentationMode =
      try await feature
      .currentPresentationModeUpdatable().value

    XCTAssertEqual(result, .plainResourcesList)
  }

  func test_availableHomePresentationModes_includesFolders_whenFoldersEnabled() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    XCTAssertTrue(modes.contains(.foldersExplorer))
  }

  func test_availableHomePresentationModes_excludesFolders_whenFoldersDisabled() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: SessionConfiguration.default
      )
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    XCTAssertFalse(modes.contains(.foldersExplorer))
  }

  func test_availableHomePresentationModes_includesTags_whenTagsEnabled() async throws {
    var configuration = SessionConfiguration.default
    configuration.tags.enabled = true
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: configuration
      )
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    XCTAssertTrue(modes.contains(.tagsExplorer))
  }

  func test_availableHomePresentationModes_excludesTags_whenTagsDisabled() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: SessionConfiguration.default
      )
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    XCTAssertFalse(modes.contains(.tagsExplorer))
  }

  func test_availableHomePresentationModes_alwaysIncludesBasicModes() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    XCTAssertTrue(modes.contains(.plainResourcesList))
    XCTAssertTrue(modes.contains(.favoriteResourcesList))
    XCTAssertTrue(modes.contains(.modifiedResourcesList))
    XCTAssertTrue(modes.contains(.sharedResourcesList))
    XCTAssertTrue(modes.contains(.ownedResourcesList))
    XCTAssertTrue(modes.contains(.expiredResourcesList))
    XCTAssertTrue(modes.contains(.resourceUserGroupsExplorer))
  }

  func test_setPresentationMode_updatesCurrentMode() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    feature.setPresentationMode(.favoriteResourcesList)

    let result: HomePresentationMode =
      try await feature
      .currentPresentationModeUpdatable().value

    XCTAssertEqual(result, .favoriteResourcesList)
  }

  func test_setPresentationMode_savesDefault_whenUseLastAsDefaultEnabled() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )

    let defaultHomePresentation: Variable<HomePresentationMode> = .init(
      initial: HomePresentationMode.plainResourcesList
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .stored(variable: defaultHomePresentation, store: { _ in })
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: true)
    )

    let feature: HomePresentation = try testedInstance()

    feature.setPresentationMode(.ownedResourcesList)

    XCTAssertEqual(defaultHomePresentation.value, .ownedResourcesList)
  }

  func test_setPresentationMode_doesNotSaveDefault_whenUseLastAsDefaultDisabled() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )

    let defaultHomePresentation: Variable<HomePresentationMode> = .init(
      initial: HomePresentationMode.plainResourcesList
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .stored(variable: defaultHomePresentation, store: { _ in })
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    feature.setPresentationMode(.ownedResourcesList)

    XCTAssertEqual(defaultHomePresentation.value, .plainResourcesList)
  }

  func test_currentPresentationModeUpdatable_notifies_whenModeChanges() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()
    let updatable = feature.currentPresentationModeUpdatable()

    let expectation = XCTestExpectation(description: "Mode change notification")
    let initialGeneration = updatable.generation

    Task {
      _ = try await updatable.notify(after: initialGeneration)
      expectation.fulfill()
    }

    try await Task.sleep(for: .milliseconds(50))
    feature.setPresentationMode(.favoriteResourcesList)

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_availableHomePresentationModes_maintainsOrder() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \AccountPreferences.defaultHomePresentation,
      with: .variable(initial: HomePresentationMode.plainResourcesList)
    )
    patch(
      \AccountPreferences.useLastHomePresentationAsDefault,
      with: .variable(initial: false)
    )

    let feature: HomePresentation = try testedInstance()

    let modes = feature.availableHomePresentationModes()

    let expectedOrder: Array<HomePresentationMode> = [
      .plainResourcesList,
      .favoriteResourcesList,
      .modifiedResourcesList,
      .sharedResourcesList,
      .ownedResourcesList,
      .expiredResourcesList,
      .foldersExplorer,
      .tagsExplorer,
      .resourceUserGroupsExplorer,
    ]

    XCTAssertEqual(Array(modes), expectedOrder)
  }
}

extension StoredVariable {

  static func stored(variable: Variable<Value>, store: @escaping @Sendable (Value) -> Void) -> Self {
    .init(
      fetch: { variable.value },
      store: { newValue in
        variable.value = newValue
        store(newValue)
      }
    )
  }
}
