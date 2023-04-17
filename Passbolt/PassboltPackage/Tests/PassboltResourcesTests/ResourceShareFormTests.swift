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
import Features
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

  var resource: Resource!

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.set(
      ResourceShareScope.self,
      context: .mock_1
    )

    self.resource = .mock_1
    use(UserGroups.placeholder)
    use(UsersPGPMessages.placeholder)
    use(ResourceShareNetworkOperation.placeholder)
    patch(
      \ResourceDetails.details,
      context: self.resource.id!,
      with: always(self.resource)
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
  }

  override func cleanup() throws {
    self.resource = .none
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
    self.resource.permissions = expectedResult

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourcePermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      await permissionsSequence.first()
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
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await permissionsSequence
        .first()
    }
  }

  func test_permissionsSequence_providesSortedPermissions() async throws {
    let expectedResult: OrderedSet<ResourcePermission> = [
      .userGroup(
        id: "existing-group",
        permission: .read,
        permissionID: "existing-group"
      ),
      .userGroup(
        id: "new-group",
        permission: .write,
        permissionID: .none
      ),
      .user(
        id: "existing-user",
        permission: .owner,
        permissionID: "existing-user"
      ),
      .user(
        id: "new-user",
        permission: .read,
        permissionID: .none
      ),
    ]
    self.resource.permissions = [
      .user(
        id: "existing-user",
        permission: .owner,
        permissionID: "existing-user"
      ),
      .userGroup(
        id: "existing-group",
        permission: .read,
        permissionID: "existing-group"
      ),
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

    await feature
      .setUserPermission("new-user", .read)
    await feature
      .setUserGroupPermission("new-group", .write)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourcePermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      await permissionsSequence.first()
    }
  }

  func test_sendForm_fails_withoutOwnerPermission() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

    await XCTAssertError(
      matches: MissingResourceOwner.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenFetchingNewGroupMembersFailsWithNewPermissions() async throws {
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceDetails.secret,
      context: resource.id!,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceDetails.secret,
      context: resource.id!,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": .string("secret")]
        )
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceDetails.secret,
      context: resource.id!,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": .string("secret")]
        )
      )
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
    self.resource.permissions = [
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
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \ResourceDetails.secret,
      context: resource.id!,
      with: { () async throws in
        uncheckedSendableResult.variable = Void()
        throw MockIssue.error()
      }
    )

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

    try await feature.sendForm()

    XCTAssertNil(result)
  }

  func test_sendForm_succeeds_whenAllOperationSucceed() async throws {
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.mock_1, .mock_1]
      )
    )
    patch(
      \ResourceDetails.secret,
      context: resource.id!,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": .string("secret")]
        )
      )
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

    await XCTAssertNoError {
      try await feature.sendForm()
    }
  }

  func test_setUserPermission_addsNewPermission_whenGivenUserHasNoPermissionYet() async throws {
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_replacesNewPermission_whenGivenUserHasNewPermission() async throws {
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_doesNotChangePermission_whenGivenUserHasPermissionWithSameType() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserPermission_updatesPermission_whenGivenUserHasPermissionWithDifferentType() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserPermission_removesPermission_whenGivenUserHasNewPermission() async throws {
    self.resource.permissions = [
      .user(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserPermission_removesPermission_whenGivenUserHasPermission() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_addsNewPermission_whenGivenUserGroupHasNoPermissionYet() async throws {
    self.resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_replacesNewPermission_whenGivenUserGroupHasNewPermission() async throws {
    self.resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_doesNotChangePermission_whenGivenUserGroupHasPermissionWithSameType() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_setUserGroupPermission_updatesPermission_whenGivenUserGroupHasPermissionWithDifferentType() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserGroupPermission_removesPermission_whenGivenUserGroupHasNewPermission() async throws {
    self.resource.permissions = [
      .userGroup(
        id: .mock_1,
        permission: .owner,
        permissionID: .mock_1
      )
    ]

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }

  func test_deleteUserGroupPermission_removesPermission_whenGivenUserGroupHasPermission() async throws {
    self.resource.permissions = [
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

    let feature: ResourceShareForm = try self.testedInstance(context: resource.id!)

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
      await feature
        .permissionsSequence()
        .first()
    }
  }
}
