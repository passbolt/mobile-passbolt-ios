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
import NetworkOperations
import OSFeatures
import Resources
import SessionData
import UIComponents

internal struct ResourceMenuController {

  internal var availableActionsPublisher: @MainActor () -> AnyPublisher<Array<Action>, Never>
  internal var resourceDetailsPublisher: @MainActor () -> AnyPublisher<Resource, Error>
  internal var performAction: @MainActor (Action) -> AnyPublisher<Void, Error>
}

extension ResourceMenuController {

  internal enum Action: Equatable {

    case openURL
    case copyURL
    case copyUsername
    case copyPassword
    case copyDescription
    case toggleFavorite(_ favorite: Bool)
    case share
    case edit
    case delete
  }
}

extension ResourceMenuController {

  internal enum Source {
    case resourceList
    case resourceDetails
  }
}

extension ResourceMenuController: UIController {

  internal typealias Context = (
    resourceID: Resource.ID,
    showShare: @MainActor (Resource.ID) -> Void,
    showEdit: @MainActor (Resource.ID) -> Void,
    showDeleteAlert: @MainActor (Resource.ID) -> Void
  )

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features =
      features.branchIfNeeded(
        scope: ResourceDetailsScope.self,
        context: context.resourceID
      ) ?? features
    let diagnostics: OSDiagnostics = features.instance()
    let linkOpener: OSLinkOpener = features.instance()
    let pasteboard: OSPasteboard = features.instance()
    let resourceController: ResourceController = try features.instance()

    func availableActionsPublisher() -> AnyPublisher<Array<Action>, Never> {
      resourceController
        .state
        .asThrowingPublisher()
        .compactMap { resource -> Array<Action>? in

          var availableActions: Array<Action> = .init()

          if resource.contains(\.meta.uri) {
            availableActions.append(.openURL)
            availableActions.append(.copyURL)
          }  // else skip

          if resource.contains(\.meta.username) {
            availableActions.append(.copyUsername)
          }  // else skip

          if resource.contains(\.secret.password) || resource.contains(\.secret) {
            availableActions.append(.copyPassword)
          }  // else skip

          if resource.contains(\.meta.description) || resource.contains(\.secret.description) {
            availableActions.append(.copyDescription)
          }  // else skip

          availableActions.append(.toggleFavorite(resource.favoriteID != .none))

          if resource.permission.canShare {
            availableActions.append(.share)
          }  // else skip

          if resource.permission.canEdit {
            availableActions.append(.edit)
            availableActions.append(.delete)
          }  // else skip

          return availableActions
        }
        .replaceError(with: [])
        .eraseToAnyPublisher()
    }

    func resourceDetailsPublisher() -> AnyPublisher<Resource, Error> {
      resourceController
        .state
        .asThrowingPublisher()
    }

    func shareAction() async throws {
      guard let resourceID: Resource.ID = try await resourceController.state.value.id
      else { throw InvalidResourceData.error() }
      context.showShare(resourceID)
    }

    func editAction() async throws {
      guard let resourceID: Resource.ID = try await resourceController.state.value.id
      else { throw InvalidResourceData.error() }
      context.showEdit(resourceID)
    }

    func deleteAction() async throws {
      guard let resourceID: Resource.ID = try await resourceController.state.value.id
      else { throw InvalidResourceData.error() }
      context.showDeleteAlert(resourceID)
    }

    func perform(action: Action) -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        switch action {
        case .openURL:
          guard let url = try await fieldValue(for: \.meta.uri).stringValue
          else {
            throw URLInvalid.error(rawString: "")
          }
          try await linkOpener.openURL(.init(rawValue: url))

        case .copyURL:
          try await pasteboard.put(
            fieldValue(for: \.meta.uri).stringValue ?? ""
          )
        case .copyPassword:
          if let password = try await fieldValue(for: \.secret.password).stringValue {
            pasteboard.put(password)
          }
          else if let password = try await fieldValue(for: \.secret).stringValue {
            pasteboard.put(password)
          }
          else {
            throw InvalidResourceSecret.error()
          }

        case .copyUsername:
          try await pasteboard.put(
            fieldValue(for: \.meta.username).stringValue ?? ""
          )
        case .copyDescription:
          if let description = try await fieldValue(for: \.secret.description).stringValue {
            pasteboard.put(description)
          }
          else if let description = try await fieldValue(for: \.meta.description).stringValue {
            pasteboard.put(description)
          }
          else {
            throw InvalidResourceSecret.error()
          }

        case .toggleFavorite:
          try await resourceController.toggleFavorite()

        case .share:
          try await shareAction()

        case .edit:
          try await editAction()

        case .delete:
          try await deleteAction()
        }
      }
      .collectErrorLog(using: diagnostics)
      .eraseToAnyPublisher()
    }

    func fieldValue(
      for field: Resource.FieldPath
    ) async throws -> JSON {
      let resource: Resource = try await resourceController.state.value
      if resource.secretContains(field) {
        try await resourceController.fetchSecretIfNeeded(force: true)
        return try await resourceController.state.value[keyPath: field]
      }
      else {
        return resource[keyPath: field]
      }
    }

    return Self(
      availableActionsPublisher: availableActionsPublisher,
      resourceDetailsPublisher: resourceDetailsPublisher,
      performAction: perform(action:)
    )
  }
}
