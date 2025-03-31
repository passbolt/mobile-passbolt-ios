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
import Display
import FeatureScopes
import Resources
import SharedUIComponents
import UICommons

/// A model representing an item in the resource creation menu.
/// Used to display available resource types that can be created.
internal struct ResourceCreateMenuItem: Equatable, Identifiable {
  /// The displayed title of the menu item
  internal var title: DisplayableString
  /// The resource specification slug identifying the type of resource
  internal var slug: ResourceSpecification.Slug
  /// The icon representing this resource type
  internal var icon: Image

  internal var id: ResourceSpecification.Slug { slug }
}

internal final class ResourceCreateMenuViewController: ViewController {

  internal typealias Context = ResourceCreatingContext

  internal struct ViewState: Equatable {
    var menuItems: [ResourceCreateMenuItem]
  }

  internal var viewState: ViewStateSource<ViewState>

  private let navigationToSelf: NavigationToResourceCreateMenu
  private let features: Features
  private let context: Context

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.navigationToSelf = try features.instance()
    self.features = features
    self.context = context
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

  /// Dismisses the resource creation menu
  internal func dismiss() async {
    await navigationToSelf.revertCatching()
  }

  /// Open relevant screen to create a new resource of the given type
  internal func create(_ slug: ResourceSpecification.Slug) async {
    await consumingErrors {
      if slug.isStandaloneTOTPType {
        try await createTOTP(slug)
      }
      else {
        try await createPassword(slug)
      }
    }
  }

  /// Prepare to create a new TOTP resource and navigate to the scanning screen
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
    else { return }
    try await self.navigationToSelf.revert()
    try await features
      .instance(of: NavigationToOTPScanning.self)
      .perform(
        context: .init(
          totpPath: totpPath
        )
      )
  }

  /// Prepare new password resource creation and navigate to the editing screen
  private func createPassword(_ slug: ResourceSpecification.Slug) async throws {
    let resourceEditPreparation: ResourceEditPreparation = try features.instance()
    let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareNew(slug, .none, .none)
    try await self.navigationToSelf.revert()
    try await features
      .instance(of: NavigationToResourceEdit.self)
      .perform(
        context: .init(
          editingContext: editingContext
        )
      )
  }
}

extension ResourceSpecification.Slug {

  internal var icon: Image {
    if isStandaloneTOTPType {
      return Image(named: .otp)
    }
    return Image(named: .key)
  }

  internal var title: DisplayableString {
    if isStandaloneTOTPType {
      return "resource.create.menu.totp"
    }
    return "resource.create.menu.password"
  }
}
