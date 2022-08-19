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

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceShareForm
  }

  var resource: ResourceDetailsDSV!

  override func prepare() throws {
    self.resource = .random()
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

  func test_loading_fails_whenAccessingDetailsFail() async throws {
    patch(
      \ResourceDetails.details,
      context: resource.id,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await self.testedInstance(context: resource.id)
    }
  }

  func test_permissionsSequence_providesCurrentPermissionsInitially() async throws {
    let expectedResult: OrderedSet<ResourceShareFormPermission> = [
      .userGroup(
        .random(),
        type: .random()
      ),
      .user(
        .random(),
        type: .random()
      ),
    ]
    self.resource.permissions = .init(
      expectedResult
        .map { permission in
          switch permission {
          case let .user(id, type):
            return .userToResource(
              id: .random(),
              userID: id,
              resourceID: resource.id,
              type: type
            )
          case let .userGroup(id, type):
            return .userGroupToResource(
              id: .random(),
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
        "existing-group",
        type: .read
      ),
      .user(
        "existing-user",
        type: .write
      ),
      .user(
        "new-user",
        type: .owner
      ),
    ]
    self.resource.permissions = [
      .userToResource(
        id: .random(),
        userID: "existing-user",
        resourceID: resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
        userGroupID: "existing-group",
        resourceID: resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    let permissionsSequence: AnyAsyncSequence<OrderedSet<ResourceShareFormPermission>> = feature.permissionsSequence()

    await feature
      .setUserPermission("new-user", .owner)
    await feature
      .setUserPermission("existing-user", .write)
    await feature
      .setUserGroupPermission("new-group", .write)
    await feature
      .deleteUserGroupPermission("new-group")

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
        id: .random(),
        userID: "existing-user",
        resourceID: resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
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

  func test_cancelForm_unloadsFeature() async throws {
    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    var loaded: Bool =
      isCached(
        ResourceShareForm.self,
        context: resource.id
      )
    XCTAssertTrue(loaded)

    await feature.cancelForm()

    loaded =
      isCached(
        ResourceShareForm.self,
        context: resource.id
      )

    XCTAssertFalse(loaded)
  }

  func test_sendForm_fails_withoutOwnerPermission() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .read
      ),
      .userGroupToResource(
        id: .random(),
        userGroupID: .random(),
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
        id: .random(),
        userID: .random(),
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
      .random(),
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
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.random(), .random()]
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
      .random(),
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
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.random(), .random()]
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
      .random(),
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
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.random(), .random()]
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
        [.random()]
      )
    )
    patch(
      \ResourceShareNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature.setUserGroupPermission(
      .random(),
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
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
        userGroupID: .random(),
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
      with: {
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
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \UserGroups.groupMembers,
      with: always(
        [.random(), .random()]
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
        [.random()]
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

  func test_sendForm_unloadsFeature_whenSucceeds() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .random(),
        userID: .random(),
        resourceID: self.resource.id,
        type: .owner
      )
    ]
    patch(
      \ResourceShareNetworkOperation.execute,
      with: always(Void())
    )

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    var loaded: Bool =
      isCached(
        ResourceShareForm.self,
        context: resource.id
      )
    XCTAssertTrue(loaded)

    try await feature.sendForm()

    loaded =
      isCached(
        ResourceShareForm.self,
        context: resource.id
      )

    XCTAssertFalse(loaded)
  }

  func test_setUserPermission_addsNewPermission_whenGivenUserHasNoPermissionYet() async throws {
    self.resource.permissions = [
      .userToResource(
        id: .random(),
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
        id: .random(),
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
        id: .random(),
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .random(),
        userID: "unchanged-user-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        "unchanged-user-id",
        .read
      )

    await XCTAssertValue(
      equal: [
        .user(
          "existing-user-id",
          type: .owner
        ),
        .user(
          "unchanged-user-id",
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
        id: .random(),
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .random(),
        userID: "changed-user-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserPermission(
        "changed-user-id",
        .write
      )

    await XCTAssertValue(
      equal: [
        .user(
          "existing-user-id",
          type: .owner
        ),
        .user(
          "changed-user-id",
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
        id: .random(),
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
        id: .random(),
        userID: "existing-user-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userToResource(
        id: .random(),
        userID: "deleted-user-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .deleteUserPermission(
        "deleted-user-id"
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

  func test_setUserGroupPermission_addsNewPermission_whenGivenUserGroupHasNoPermissionYet() async throws {
    self.resource.permissions = [
      .userGroupToResource(
        id: .random(),
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
        id: .random(),
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
        id: .random(),
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
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
        id: .random(),
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
        userGroupID: "changed-user-group-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .setUserGroupPermission(
        "changed-user-group-id",
        .write
      )

    await XCTAssertValue(
      equal: [
        .userGroup(
          "existing-user-group-id",
          type: .owner
        ),
        .userGroup(
          "changed-user-group-id",
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
        id: .random(),
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
        id: .random(),
        userGroupID: "existing-user-group-id",
        resourceID: self.resource.id,
        type: .owner
      ),
      .userGroupToResource(
        id: .random(),
        userGroupID: "deleted-user-group-id",
        resourceID: self.resource.id,
        type: .read
      ),
    ]

    let feature: ResourceShareForm = try await self.testedInstance(context: resource.id)

    await feature
      .deleteUserGroupPermission(
        "deleted-user-group-id"
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
}
