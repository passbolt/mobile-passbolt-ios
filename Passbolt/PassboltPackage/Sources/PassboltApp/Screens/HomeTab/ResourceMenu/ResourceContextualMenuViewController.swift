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
import SharedUIComponents

internal enum ResourceContextualMenuItem: Hashable, Identifiable {

  case openURI
  case copyURI
  case copyUsername
  case copyPassword
  case copyDescription
  case copyNote

  case toggle(favorite: Bool)

  case share
  case editResource(isStandaloneTOTP: Bool)

  case delete

  internal var id: Self { self }
}

internal final class ResourceContextualMenuViewController: ViewController {

  internal struct Context {

    internal var revealOTP: (@MainActor () async -> Void)?
  }

  internal struct ViewState: Equatable {

    internal var title: String
    internal var accessMenuItems: Array<ResourceContextualMenuItem>
    internal var modifyMenuItems: Array<ResourceContextualMenuItem>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let resourceController: ResourceController

  private let navigationToSelf: NavigationToResourceContextualMenu
  private let navigationToDeleteAlert: NavigationToResourceDeleteAlert
  private let navigationToShare: NavigationToResourceShare
  private let navigationToResourceEdit: NavigationToResourceEdit
  private let navigationToResourceOTPMenu: NavigationToResourceOTPContextualMenu

  private let linkOpener: OSLinkOpener
  private let pasteboard: OSPasteboard

  private let resourceID: Resource.ID

  private let sessionConfiguration: SessionConfiguration

  private let features: Features

  private let context: Context

  internal init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(ResourceScope.self)
    self.resourceID = try features.context(of: ResourceScope.self)

    self.context = context

    self.features = features.takeOwned()

    self.sessionConfiguration = try features.sessionConfiguration()

    self.linkOpener = features.instance()
    self.pasteboard = features.instance()

    self.navigationToSelf = try features.instance()
    self.navigationToDeleteAlert = try features.instance()
    self.navigationToShare = try features.instance()
    self.navigationToResourceEdit = try features.instance()
    self.navigationToResourceOTPMenu = try features.instance()

    self.resourceController = try features.instance()

    self.viewState = .init(
      initial: .init(
        title: "",
        accessMenuItems: .init(),
        modifyMenuItems: .init()
      ),
      updateFrom: self.resourceController.state,
      update: { [sessionConfiguration, navigationToSelf] (updateState, update: Update<Resource>) in
        do {
          let resource: Resource = try update.value
          var accessMenuItems: Array<ResourceContextualMenuItem> = .init()
          var modifyMenuItems: Array<ResourceContextualMenuItem> = .init()

          if resource.contains(\.meta.uris), resource[keyPath: \.meta.uris].arrayValue?.isEmpty == false {
            accessMenuItems.append(.openURI)
            accessMenuItems.append(.copyURI)
          }  // else NOP

          if resource.contains(\.meta.username) {
            accessMenuItems.append(.copyUsername)
          }  // else NOP

          if resource.hasPassword && sessionConfiguration.resources.passwordCopyEnabled {
            accessMenuItems.append(.copyPassword)
          }  // else NOP

          if resource.contains(\.meta.description) {
            accessMenuItems.append(.copyDescription)
          }  // else NOP

          if resource.contains(\.secret.description) {
            accessMenuItems.append(.copyNote)
          }  // else NOP

          modifyMenuItems.append(.toggle(favorite: resource.favorite))

          if resource.permission.canShare,
            sessionConfiguration.share.showMembersList
          {
            modifyMenuItems.append(.share)
          }  // else NOP

          if resource.canEdit {
            if resource.hasPassword {
              modifyMenuItems.append(.editResource(isStandaloneTOTP: false))
            }
            else if resource.hasTOTP {
              modifyMenuItems.append(.editResource(isStandaloneTOTP: true))
            }

            modifyMenuItems.append(.delete)
          }  // else NOP

          updateState { (viewState: inout ViewState) in
            viewState.title = resource.name
            viewState.accessMenuItems = accessMenuItems
            viewState.modifyMenuItems = modifyMenuItems
          }
        }
        catch {
          await navigationToSelf.revertCatching()
          SnackBarMessageEvent.send(.error(error))
        }
      }
    )
  }
}

extension ResourceContextualMenuViewController {

  internal func performAction(
    for item: ResourceContextualMenuItem
  ) async {
    switch item {
    case .openURI:
      await self.openURL(field: \.meta.uris)

    case .copyURI:
      await self.copy(field: \.meta.uris)

    case .copyUsername:
      await self.copy(field: \.meta.username)

    case .copyPassword:
      // using \.firstPassword to find first field with password
      // semantics, actual password have different path
      await self.copy(field: \.firstPassword)

    case .copyDescription:
      // using \.description to find proper description field
      // actual description have different path
      await self.copy(field: \.description)
    case .copyNote:
      await self.copy(field: \.secret.description)

    case .toggle(favorite: _):
      await self.toggleFavorite()

    case .share:
      await self.share()

    case .editResource(_):
      await self.editPassword()

    case .delete:
      await self.delete()
    }
  }

  private func openURL(
    field path: Resource.FieldPath
  ) async {
    await consumingErrors { () async throws -> Void in
      var resource: Resource = try await self.resourceController.state.value

      guard let field: ResourceFieldSpecification = resource.fieldSpecification(for: path)
      else {
        throw
          UnknownResourceField
          .error(
            "Attempting to access not existing resource field value!",
            path: path,
            value: .null
          )
      }

      if field.encrypted {
        _ = try await self.resourceController.fetchSecretIfNeeded()
        resource = try await self.resourceController.state.value
      }  // else continue

      var path = path
      if field.content == .list {
        // if field is list, we take first element
        path = path.appending(path: \.0)
      }

      try await self.linkOpener.openURL(.init(rawValue: resource[keyPath: path].stringValue ?? ""))

      try await self.navigationToSelf.revert()
    }
  }

  private func copy(
    field path: Resource.FieldPath
  ) async {
    await consumingErrors { () async throws -> Void in
      var resource: Resource = try await self.resourceController.state.value

      guard let field: ResourceFieldSpecification = resource.fieldSpecification(for: path)
      else {
        throw
          UnknownResourceField
          .error(
            "Attempting to access not existing resource field value!",
            path: path,
            value: .null
          )
      }

      if field.encrypted {
        _ = try await self.resourceController.fetchSecretIfNeeded()
        resource = try await self.resourceController.state.value
      }  // else continue

      var path = path
      if field.content == .list {
        // if field is list, we take first element
        path = path.appending(path: \.0)
      }
      self.pasteboard.put(
        resource[keyPath: path].stringValue ?? "",
        withAutoExpiration: resource.isEncrypted(path)
      )
      
      try await self.navigationToSelf.revert()

      SnackBarMessageEvent.send(
        .info(
          .localized(
            key: "resource.menu.item.field.copied",
            arguments: [
              field.name.displayable.string()
            ]
          )
        )
      )
    }
  }

  private func toggleFavorite() async {
    await consumingErrors {
      try await self.resourceController.toggleFavorite()
      let resource: Resource = try await self.resourceController.state.value
      try await self.navigationToSelf.revert()
      if resource.favorite {
        SnackBarMessageEvent.send(
          .info(
            .localized(
              key: "resource.menu.action.favorite.added",
              arguments: [resource.name]
            )
          )
        )
      }
      else {
        SnackBarMessageEvent.send(
          .info(
            .localized(
              key: "resource.menu.action.favorite.removed",
              arguments: [resource.name]
            )
          )
        )
      }
    }
  }

  private func share() async {
    await consumingErrors {
      try await self.navigationToSelf.revert()
      try await self.navigationToShare.perform(context: self.resourceID)
    }
  }

  private func editPassword() async {
    await consumingErrors { [resourceID] in
      let resourceEditPreparation: ResourceEditPreparation = try features.instance()
      let editingContext: ResourceEditingContext = try await resourceEditPreparation.prepareExisting(resourceID)
      try await self.navigationToSelf.revert()
      try await self.navigationToResourceEdit.perform(
        context: .init(
          editingContext: editingContext
        )
      )
    }
  }

  private func delete() async {
    await consumingErrors {
      try await self.navigationToSelf.revert(animated: true)
      try await self.navigationToDeleteAlert.perform(
        context: .init(
          resourceID: self.resourceID
        )
      )
    }
  }

  internal func dismiss() async {
    await navigationToSelf.revertCatching()
  }
}
