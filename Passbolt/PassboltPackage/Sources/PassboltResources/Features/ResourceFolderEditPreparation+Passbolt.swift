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

import DatabaseOperations
import FeatureScopes
import Features
import Resources
import SessionData

extension ResourceFolderEditPreparation {

	@MainActor fileprivate static func load(
		using features: Features
	) throws -> ResourceFolderEditPreparation {
		let currentAccount: Account = try features.sessionAccount()
		let sessionData: SessionData = try features.instance()

		let resourceFolderDetailsFetchDatabaseOperation: ResourceFolderDetailsFetchDatabaseOperation =
			try features.instance()

		@Sendable nonisolated func prepareNew(
			parentFolderID: ResourceFolder.ID?
		) async throws -> FeaturesContainer {
			try await sessionData.refreshIfNeeded()
			let resourceFolder: ResourceFolder
			if let parentFolderID {
				let parentFolder: ResourceFolder = try await resourceFolderDetailsFetchDatabaseOperation(parentFolderID)

				guard parentFolder.permission.canEdit
				else {
					throw
					InvalidResourceFolderPermission
						.error(message: "Attempting to create a resource folder without edit permission in parent folder")
						.recording(parentFolder, for: "parentFolder")
				}

				var folderPath: OrderedSet<ResourceFolderPathItem> = parentFolder.path
				folderPath.append(
					.init(
						id: parentFolderID,
						name: parentFolder.name,
						shared: parentFolder.shared
					)
				)
				resourceFolder = .init(
					id: .none, // local does not have ID
					name: "",
					path: folderPath,
					// inherit permissions from the parent folder
					permission: parentFolder.permission,
					permissions: parentFolder.permissions
						.map { (permission: ResourceFolderPermission) -> ResourceFolderPermission in
							switch permission {
							case .user(let id, let permission, _):
								return .user(
									id: id,
									permission: permission,
									permissionID: .none // local does not have ID
								)
							case .userGroup(let id, let permission, _):
								return .userGroup(
									id: id,
									permission: permission,
									permissionID: .none // local does not have ID
								)
							}
						}
						.asOrderedSet()
				)
			}
			else {
				resourceFolder = .init(
					id: .none, // local does not have ID
					name: "",
					path: .init(),
					permission: .owner,
					permissions: [
						.user(
							id: currentAccount.userID,
							permission: .owner,
							permissionID: .none // local does not have ID
						)
					]
				)
			}

			return try await features
				.branch(
					scope: ResourceFolderEditScope.self,
					context: .init(
						editedResourceFolder: resourceFolder
					)
				)
		}

		@Sendable nonisolated func prepareExisting(
			resourceFolderID: ResourceFolder.ID
		) async throws -> FeaturesContainer {
			try await sessionData.refreshIfNeeded()
			let resourceFolder: ResourceFolder = try await resourceFolderDetailsFetchDatabaseOperation(resourceFolderID)

			guard resourceFolder.permission.canEdit
			else {
				throw
				InvalidResourceFolderPermission
					.error(message: "Attempting to edit a resource folder without edit permission")
					.recording(resourceFolder, for: "resourceFolder")
			}

			return try await features
				.branch(
					scope: ResourceFolderEditScope.self,
					context: .init(
						editedResourceFolder: resourceFolder
					)
				)
		}

		return .init(
			prepareNew: prepareNew(parentFolderID:),
			prepareExisting: prepareExisting(resourceFolderID:)
		)
	}
}

extension FeaturesRegistry {

	internal mutating func usePassboltResourceFolderEditPreparation() {
		self.use(
			.disposable(
				ResourceFolderEditPreparation.self,
				load: ResourceFolderEditPreparation.load(using:)
			),
			in: SessionScope.self
		)
	}
}
