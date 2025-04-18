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
import OSFeatures
import Resources
import SharedUIComponents

internal final class ResourcesListCreateMenuViewController: ViewController {

  private let navigation: DisplayNavigation

  private let context: Context
  private let features: Features

  internal var viewState: ViewStateSource<ViewState>

  internal struct ViewState: Equatable {
    var menuItems: [ResourceCreateMenuItem]
  }

  internal struct Context {
    internal let folderID: ResourceFolder.ID?
    internal let availableTypes: [ResourceType]
  }

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.navigation = try features.instance()

    let menuItems: Array<ResourceCreateMenuItem> = context.availableTypes.map {
      .init(
        title: $0.specification.slug.title,
        slug: $0.specification.slug,
        icon: $0.specification.slug.icon
      )
    }
    self.viewState = .init(
      initial: .init(menuItems: menuItems)
    )
  }
}

extension ResourcesListCreateMenuViewController {

  /// Dismisses the current resource creation menu sheet
  internal final func close() async {
    await self.navigation
      .dismissLegacySheet(ResourcesListCreateMenuView.self)
  }

  /// Creates a new folder at the current location
  /// - Throws: Error when folder creation preparation fails
  internal final func createFolder() async throws {
    await self.navigation
      .dismissLegacySheet(ResourcesListCreateMenuView.self)
    let editingFeatures: Features = try await self.features.instance(of: ResourceFolderEditPreparation.self)
      .prepareNew(context.folderID)
    try await self.navigation.push(
      ResourceFolderEditView.self,
      controller: editingFeatures.instance()
    )
  }

  /// Creates a new resource based on the provided slug type
  /// - Parameter slug: Resource specification slug determining the type of resource to create
  internal func createResource(_ slug: ResourceSpecification.Slug) async {
    await consumingErrors {
      do {
        if slug.isStandaloneTOTPType {
          try await createTOTP(slug)
        }
        else {
          try await createPassword(slug)
        }
      }
      catch is InvalidResourceTypeError {
        SnackBarMessageEvent.send(.error("resource.create.invalid.configuration"))
      }
    }
  }

  /// Creates a new TOTP resource
  /// - Parameter slug: Resource specification slug for TOTP type
  /// - Throws: Error when TOTP resource creation preparation fails
  private func createTOTP(_ slug: ResourceSpecification.Slug) async throws {
    let resourceEditPreparation: ResourceEditPreparation = try features.instance()
    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(slug, .none, .none)
    let features: Features =
      try features
      .branch(
        scope: ResourceEditScope.self,
        context: editingContext
      )
    guard
      let attachType: ResourceType = context.availableTypes.first(where: {
        $0.specification.slug == slug
      }),
      let totpPath: ResourceType.FieldPath = attachType.fieldSpecification(for: \.firstTOTP)?.path
    else {
      throw InvalidResourceTypeError.error()
    }
    await self.navigation.dismissLegacySheet(ResourcesListCreateMenuView.self)
    try await features
      .instance(of: NavigationToOTPScanning.self)
      .perform(
        context: .init(
          totpPath: totpPath
        )
      )
  }

  /// Creates a new password resource
  /// - Parameter slug: Resource specification slug for password type
  /// - Throws: Error when password resource creation preparation fails
  private func createPassword(_ slug: ResourceSpecification.Slug) async throws {
    let resourceEditPreparation: ResourceEditPreparation = try features.instance()
    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(slug, .none, .none)
    await self.navigation.dismissLegacySheet(ResourcesListCreateMenuView.self)
    try await features
      .instance(of: NavigationToResourceEdit.self)
      .perform(
        context: .init(
          editingContext: editingContext
        )
      )
  }
}
