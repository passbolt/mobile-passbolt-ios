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

import Commons
import FeatureScopes
import OSFeatures
import SessionData
import Shared
import TestExtensions
import Users

@testable import Display
@testable import Resources
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ConfirmPermissionDetailsControllerTests: FeaturesTestCase {

  /// Levels reported back to the recipient list, in order.
  private let appliedPermissions: CriticalState<Array<Permission>> = .init(.init())
  /// Number of times the recipient was dropped from the list.
  private let removals: CriticalState<Int> = .init(0)
  /// Navigation performed by the screen, in order.
  private let navigationEvents: CriticalState<Array<String>> = .init(.init())

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \Users.userAvatarImage,
      with: always(Data?.none)
    )
    patch(
      \NavigationToConfirmUserPermissionDetails.mockRevert,
      with: { (_: Bool) in
        self.navigationEvents.access { (events: inout Array<String>) in events.append("revert") }
      }
    )
    patch(
      \NavigationToConfirmGroupPermissionDetails.mockRevert,
      with: { (_: Bool) in
        self.navigationEvents.access { (events: inout Array<String>) in events.append("revert") }
      }
    )
  }
}

// MARK: - User recipient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionDetailsControllerTests {

  func test_selectPermission_reportsNothing_untilApplied() async throws {
    let tested: ConfirmUserPermissionDetailsController = try self.testedUser()

    tested.selectPermission(.owner)

    let selectedPermission = await tested.viewState.current.selectedPermission
    XCTAssertEqual(selectedPermission, .owner, "The radio button moves")
    XCTAssertTrue(self.appliedPermissions.get().isEmpty, "Nothing reaches the list before Apply")
    XCTAssertTrue(self.navigationEvents.get().isEmpty, "The screen stays up")
  }

  func test_apply_reportsThePickedLevel_andLeaves() async throws {
    let tested: ConfirmUserPermissionDetailsController = try self.testedUser()
    tested.selectPermission(.owner)

    await tested.apply()

    XCTAssertEqual(self.appliedPermissions.get(), [.owner])
    XCTAssertEqual(self.removals.get(), 0)
    XCTAssertEqual(self.navigationEvents.get(), ["revert"])
  }

  func test_remove_dropsTheRecipient_andLeaves() async throws {
    let tested: ConfirmUserPermissionDetailsController = try self.testedUser()
    // A level picked but never applied must not travel with the removal.
    tested.selectPermission(.owner)

    await tested.remove()

    XCTAssertEqual(self.removals.get(), 1)
    XCTAssertTrue(self.appliedPermissions.get().isEmpty)
    XCTAssertEqual(self.navigationEvents.get(), ["revert"])
  }
}

// MARK: - Group recipient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionDetailsControllerTests {

  func test_group_selectPermission_reportsNothing_untilApplied() async throws {
    let tested: ConfirmGroupPermissionDetailsController = try self.testedGroup()

    tested.selectPermission(.owner)
    let selectedPermission = await tested.viewState.current.selectedPermission
    XCTAssertEqual(selectedPermission, .owner)
    XCTAssertTrue(self.appliedPermissions.get().isEmpty)
    XCTAssertTrue(self.navigationEvents.get().isEmpty)
  }

  func test_group_apply_reportsThePickedLevel_andLeaves() async throws {
    let tested: ConfirmGroupPermissionDetailsController = try self.testedGroup()
    tested.selectPermission(.write)

    await tested.apply()

    XCTAssertEqual(self.appliedPermissions.get(), [.write])
    XCTAssertEqual(self.navigationEvents.get(), ["revert"])
  }

  func test_group_remove_dropsTheRecipient_andLeaves() async throws {
    let tested: ConfirmGroupPermissionDetailsController = try self.testedGroup()

    await tested.remove()

    XCTAssertEqual(self.removals.get(), 1)
    XCTAssertTrue(self.appliedPermissions.get().isEmpty)
    XCTAssertEqual(self.navigationEvents.get(), ["revert"])
  }
}

// MARK: - Read-only rows

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionDetailsControllerTests {

  /// A read-only list offers neither the level picker nor a way out of the permission - there is nothing on it
  /// the operator is entitled to change.
  func test_state_offersNoActions_whenTheListIsReadOnly() async throws {
    let tested: ConfirmUserPermissionDetailsController = try self.testedUser(editable: false)

    let state: ConfirmUserPermissionDetailsController.ViewState = await tested.viewState.current

    XCTAssertFalse(state.editable)
  }
}

// MARK: - Test helpers

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension ConfirmPermissionDetailsControllerTests {

  private func testedUser(
    editable: Bool = true
  ) throws -> ConfirmUserPermissionDetailsController {
    try self.testedInstance(
      context: .init(
        details: .mock_1,
        editable: editable,
        setPermission: { (permission: Permission) in
          self.appliedPermissions.access { (levels: inout Array<Permission>) in levels.append(permission) }
        },
        remove: {
          self.removals.access { (count: inout Int) in count += 1 }
        }
      )
    )
  }

  private func testedGroup() throws -> ConfirmGroupPermissionDetailsController {
    try self.testedInstance(
      context: .init(
        details: .mock_1,
        editable: true,
        setPermission: { (permission: Permission) in
          self.appliedPermissions.access { (levels: inout Array<Permission>) in levels.append(permission) }
        },
        remove: {
          self.removals.access { (count: inout Int) in count += 1 }
        }
      )
    )
  }
}
