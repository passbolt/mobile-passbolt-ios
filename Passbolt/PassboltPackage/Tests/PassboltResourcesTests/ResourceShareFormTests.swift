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
import CommonModels
import FeatureScopes
import Features
import Metadata
import SessionData
import TestExtensions
import Users
import XCTest

@testable import PassboltResources
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceShareFormTests: LoadableFeatureTestCase<ResourceShareForm> {

  override class var testedImplementationScope: any FeaturesScope.Type { ResourceShareScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceShareForm()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.set(
      ResourceShareScope.self
    )
    self.set(
      ResourceScope.self,
      context: .mock_1
    )
    use(UserGroups.placeholder)
    use(UsersPGPMessages.placeholder)
    use(ResourceShareNetworkOperation.placeholder)
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
  }

  func test_permissionsSequence_providesCurrentPermissionsInitially() async throws {
    let expectedResult: OrderedSet<ResourcePermission> = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    var resource: Resource = .mock_1
    resource.permissions = expectedResult
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourcePermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try? await permissionsSequence.first()
    }
  }

  func test_permissionsSequence_updatesWhenPermissionsChange() async throws {
    let expectedResult: OrderedSet<ResourcePermission> = [
      .userGroup(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_1,
        permission: .write,
        permissionID: .mock_2
      ),
      .user(
        id: .mock_2,
        permission: .owner,
        permissionID: .none
      ),
    ]
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourcePermission>> = feature.permissionsSequence()

    await feature
      .setUserPermission(.mock_2, .owner)
    await feature
      .setUserPermission(.mock_1, .write)
    await feature
      .setUserGroupPermission(.mock_2, .write)
    await feature
      .deleteUserGroupPermission(.mock_2)

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try? await permissionsSequence
        .first()
    }
  }

  func test_permissionsSequence_providesSortedPermissions() async throws {
    let expectedResult: OrderedSet<ResourcePermission> = [
      .userGroup(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_2,
        permission: .write,
        permissionID: .none
      ),
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_2,
        permission: .read,
        permissionID: .none
      ),
    ]
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_1
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(.mock_2, .read)
    await feature
      .setUserGroupPermission(.mock_2, .write)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourcePermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try? await permissionsSequence.first()
    }
  }

  func test_sendForm_fails_withoutOwnerPermission() async throws {

    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .read,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_1,
        permission: .write,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await XCTAssertError(
      matches: MissingResourceOwner.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenFetchingNewGroupMembersFailsWithNewPermissions() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \UserGroups.groupMembers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature.setUserGroupPermission(
      .mock_1,
      .read
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenAccessingSecretFailsWithNewPermissions() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature.setUserGroupPermission(
      .mock_1,
      .read
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenEncryptingSecretFailsWithNewPermissions() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always([
        "password": "secret"
      ])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature.setUserGroupPermission(
      .mock_1,
      .read
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenNetworkRequestFails() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always([
        "password": "secret"
      ])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always(
        [.mock_1]
      )
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ResourceSharePreparation.prepareResourceForSharing,
      with: always(Void())
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature.setUserGroupPermission(
      .mock_1,
      .read
    )

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_doesNotRequestSecret_withoutNewPermissions() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    let result: UnsafeSendable<Void?> = .init()

    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: { (_: Bool) async throws in
        result.value = Void()
        throw MockIssue.error()
      }
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    try await feature.sendForm()

    XCTAssertNil(result.value)
  }

  func test_sendForm_succeeds_whenAllOperationSucceed() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always([
        "password": "secret"
      ])
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: always(
        [.mock_1]
      )
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \MetadataKeysService.validatePinnedKey,
      with: always(.valid)
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await XCTAssertNoError {
      try await feature.sendForm()
    }
  }

  func test_setUserPermission_addsNewPermission_whenGivenUserHasNoPermissionYet() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(
        .mock_2,
        .read
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .user(
          id: .mock_2,
          permission: .read,
          permissionID: .none
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_replacesNewPermission_whenGivenUserHasNewPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(
        .mock_2,
        .read
      )

    await feature
      .setUserPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .user(
          id: .mock_2,
          permission: .write,
          permissionID: .none
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_doesNotChangePermission_whenGivenUserHasPermissionWithSameType() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(
        .mock_2,
        .read
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .user(
          id: .mock_2,
          permission: .read,
          permissionID: .mock_2
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_updatesPermission_whenGivenUserHasPermissionWithDifferentType() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .user(
          id: .mock_2,
          permission: .write,
          permissionID: .mock_2
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserPermission_removesPermission_whenGivenUserHasNewPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserPermission(
        .mock_2,
        .read
      )

    await feature
      .deleteUserPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        )
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserPermission_removesPermission_whenGivenUserHasPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .user(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .deleteUserPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .user(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        )
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_addsNewPermission_whenGivenUserGroupHasNoPermissionYet() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserGroupPermission(
        .mock_2,
        .read
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .userGroup(
          id: .mock_2,
          permission: .read,
          permissionID: .none
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_replacesNewPermission_whenGivenUserGroupHasNewPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserGroupPermission(
        .mock_2,
        .read
      )

    await feature
      .setUserGroupPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .userGroup(
          id: .mock_2,
          permission: .write,
          permissionID: .none
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_doesNotChangePermission_whenGivenUserGroupHasPermissionWithSameType() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserGroupPermission(
        .mock_2,
        .read
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .userGroup(
          id: .mock_2,
          permission: .read,
          permissionID: .mock_2
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_updatesPermission_whenGivenUserGroupHasPermissionWithDifferentType() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserGroupPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        ),
        .userGroup(
          id: .mock_2,
          permission: .write,
          permissionID: .mock_2
        ),
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserGroupPermission_removesPermission_whenGivenUserGroupHasNewPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .setUserGroupPermission(
        .mock_2,
        .read
      )

    await feature
      .deleteUserGroupPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        )
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserGroupPermission_removesPermission_whenGivenUserGroupHasPermission() async throws {
    var resource: Resource = .mock_1
    resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      ),
      .userGroup(
        id: .mock_2,
        permission: .read,
        permissionID: .mock_2
      ),
    ]
    patch(
      \ResourceController.state,
      with: Variable(initial: resource).asAnyUpdatable()
    )

    let feature: ResourceShareForm = try self.testedInstance()

    await feature
      .deleteUserGroupPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          id: .mock_1,
          permission: .owner,
          permissionID: .mock_1
        )
      ]
    ) {
      try? await feature
        .permissionsSequence()
        .first()
    }
  }
}
