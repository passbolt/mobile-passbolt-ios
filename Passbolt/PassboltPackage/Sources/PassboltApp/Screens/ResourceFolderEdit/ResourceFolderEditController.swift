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

import Display
import FeatureScopes
import OSFeatures
import Resources
import Users

internal final class ResourceFolderEditController: ViewController {

	internal nonisolated let viewState: ViewStateSource<ViewState>

	private let navigation: DisplayNavigation
	private let users: Users
	private let resourceFolderEditForm: ResourceFolderEditForm

	private let features: Features

	internal init(
		context: Void,
		features: Features
	) throws {
		self.features = features.takeOwned()
		self.navigation = try features.instance()
		self.users = try features.instance()
		self.resourceFolderEditForm = try features.instance()

		self.viewState = .init(
			initial: .init(
				folderName: .valid(""),
				folderLocation: .init(),
				folderPermissionItems: .init()
			),
			updateFrom: self.resourceFolderEditForm.state,
      update: { [users] (updateState, formState) in
        do {
          let resourceFolder: ResourceFolder = try formState.value
          let resourceFolderPermissions: Array<OverlappingAvatarStackView.Item> = try await resourceFolder.permissions.asyncMap { (permission: ResourceFolderPermission) in
            switch permission {
            case .user(let id, _, _):
              return await .user(
                id,
                avatarImage: users.avatarImage(for: id),
                isSuspended: try users.userDetails(id).isSuspended
              )

            case .userGroup(let id, _, _):
              return .userGroup(id)
            }
          }
          updateState { (viewState: inout ViewState) in
            viewState.folderName = resourceFolder.nameValidator.validate(resourceFolder.name)
            viewState.folderLocation = resourceFolder.path.map(\.name)
            viewState.folderPermissionItems = resourceFolderPermissions
          }
      }
        catch {
          error.consume()
        }
			}
		)
	}
}

extension ResourceFolderEditController {

	internal struct ViewState: Equatable {

		internal var folderName: Validated<String>
		internal var folderLocation: Array<String>
		internal var folderPermissionItems: Array<OverlappingAvatarStackView.Item>
	}
}

extension ResourceFolderEditController {

	@Sendable nonisolated internal final func setFolderName(
		_ folderName: String
	) {
		self.resourceFolderEditForm.setFolderName(folderName)
	}

	internal final func saveChanges() async {
		do {
			try await self.resourceFolderEditForm.sendForm()
			await self.navigation.pop(ResourceFolderEditView.self)
		}
		catch {
			error.consume()
		}
	}
}
