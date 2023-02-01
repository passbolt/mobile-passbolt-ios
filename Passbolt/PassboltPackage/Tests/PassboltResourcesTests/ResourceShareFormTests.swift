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

  var resource: ResourceDetailsDSV!

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
      context: self.resource.id,
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
    let expectedResult: OrderedSet<ResourceShareFormPermission> = [
      .userGroup(
        .mock_1,
        type: .owner
      ),
      .user(
        .mock_1,
        type: .read
      ),
    ]
    self.resource.permissions = .init(
      expectedResult
        .map { permission in
          switch permission {
          case let .user(id, type):
            return .userToResource(
              id: .mock_1,
              userID: id,
              resourceID: resource.id,
              type: type
            )
          case let .userGroup(id, type):
            return .userGroupToResource(
              id: .mock_1,
              userGroupID: id,
              resourceID: resource.id,
              type: type
            )
          }
        }
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      await permissionsSequence.first()
    }
  }

  func test_permissionsSequence_updatesWhenPermissionsChange() async throws {
    let expectedResult: OrderedSet<ResourceShareFormPermission> = [
      .userGroup(
        .mock_1,
        type: .read
      ),
      .user(
        .mock_1,
        type: .write
      ),
      .user(
        .mock_2,
        type: .owner
      ),
    ]
    self.resource.permissions = [
      .userGroupToResource(
        id: .mock_1,
        userGroupID: .mock_1,
        resourceID: resource.id,
        type: .read
      ),
      .userToResource(
        id: .mock_2,
        userID: .mock_1,
        resourceID: resource.id,
        type: .owner
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> = feature.permissionsSequence()

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
    let expectedResult: OrderedSet<ResourceShareFormPermission> = [
      .userGroup(
        "existing-group",
        type: .read
      ),
      .userGroup(
        "new-group",
        type: .write
      ),
      .user(
        "existing-user",
        type: .owner
      ),
      .user(
        "new-user",
        type: .read
      ),
    ]
    self.resource.permissions = [
      .userToResource(
        id: .mock_1,
        userID: "existing-user",
        resourceID: resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "existing-group",
        resourceID: resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission("new-user", .read)
    await feature
      .setUserGroupPermission("new-group", .write)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> = feature.permissionsSequence()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      await permissionsSequence.first()
    }
  }

  func test_sendForm_fails_withoutOwnerPermission() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .read
      ),
      .userGroupToResource(
        id: .mock_1,
        userGroupID: .mock_1,
        resourceID: self.resource.id,
        type: .write
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await XCTAssertError(
      matches: MissingResourceOwner.self
    ) {
      try await feature.sendForm()
    }
  }

  func test_sendForm_fails_whenFetchingNewGroupMembersFailsWithNewPermissions() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
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
      context: resource.id,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
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
      context: resource.id,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
        )
      )
    )
    patch(
      \UsersPGPMessages.encryptMessageForUsers,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
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
      context: resource.id,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
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

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .mock_1,
        userGroupID: .mock_1,
        resourceID: self.resource.id,
        type: .write
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
      context: resource.id,
      with: { () async throws in
        uncheckedSendableResult.variable = Void()
        throw MockIssue.error()
      }
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    try await feature.sendForm()

    XCTAssertNil(result)
  }

  func test_sendForm_succeeds_whenAllOperationSucceed() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
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
      context: resource.id,
      with: always(
        .init(
          rawValue: "{\"password\":\"secret\"}",
          values: ["password": "secret"]
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

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await XCTAssertNoError {
      try await feature.sendForm()
    }
  }

  func test_setUserPermission_addsNewPermission_whenGivenUserHasNoPermissionYet() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .mock_1,
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        "new-user-id",
        .read
      )

    await XCTAssertValue(
      equal: [
        .user(
          "existing-user-id",
          type: .owner
        ),
        .user(
          "new-user-id",
          type: .read
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
      .userToResource(
        id: .mock_1,
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        "new-user-id",
        .read
      )

    await feature
      .setUserPermission(
        "new-user-id",
        .write
      )

    await XCTAssertValue(
      equal: [
        .user(
          "existing-user-id",
          type: .owner
        ),
        .user(
          "new-user-id",
          type: .write
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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .mock_2,
        userID: .mock_2,
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        .mock_2,
        .read
      )

    await XCTAssertValue(
      equal: [
        .user(
          .mock_1,
          type: .owner
        ),
        .user(
          .mock_2,
          type: .read
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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .mock_2,
        userID: .mock_2,
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .user(
          .mock_1,
          type: .owner
        ),
        .user(
          .mock_2,
          type: .write
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
      .userToResource(
        id: .mock_1,
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        "new-user-id",
        .read
      )

    await feature
      .deleteUserPermission(
        "new-user-id"
      )

    await XCTAssertValue(
      equal: [
        .user(
          "existing-user-id",
          type: .owner
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
      .userToResource(
        id: .mock_1,
        userID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .mock_2,
        userID: .mock_2,
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .deleteUserPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .user(
          .mock_1,
          type: .owner
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        "new-user-group-id",
        .read
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          "existing-user-group-id",
          type: .owner
        ),
        .userGroup(
          "new-user-group-id",
          type: .read
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        "new-user-group-id",
        .read
      )

    await feature
      .setUserGroupPermission(
        "new-user-group-id",
        .write
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          "existing-user-group-id",
          type: .owner
        ),
        .userGroup(
          "new-user-group-id",
          type: .write
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "unchanged-user-group-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        "unchanged-user-group-id",
        .read
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          "existing-user-group-id",
          type: .owner
        ),
        .userGroup(
          "unchanged-user-group-id",
          type: .read
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .mock_2,
        userGroupID: .mock_2,
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        .mock_2,
        .write
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          .mock_1,
          type: .owner
        ),
        .userGroup(
          .mock_2,
          type: .write
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      )
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        "new-user-group-id",
        .read
      )

    await feature
      .deleteUserGroupPermission(
        "new-user-group-id"
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          "existing-user-group-id",
          type: .owner
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
      .userGroupToResource(
        id: .mock_1,
        userGroupID: .mock_1,
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .mock_2,
        userGroupID: .mock_2,
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .deleteUserGroupPermission(
        .mock_2
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          .mock_1,
          type: .owner
        )
      ]
    ) {
      await feature
        .permissionsSequence()
        .first()
    }
  }
}
