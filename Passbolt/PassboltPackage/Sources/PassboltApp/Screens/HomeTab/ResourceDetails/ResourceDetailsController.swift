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
import OSFeatures
import Resources
import SessionData
import UIComponents

internal struct ResourceDetailsController {

  internal var statePublisher: @MainActor () -> AnyPublisher<State, Error>
  internal var toggleDecrypt: @MainActor (ResourceFieldSpecification) -> AnyPublisher<String?, Error>
  internal var presentResourceMenu: @MainActor () -> Void
  internal var presentResourceShare: @MainActor (Resource.ID) -> Void
  internal var presentResourceEdit: @MainActor (Resource.ID) -> Void
  internal var resourceSharePresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceEditPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var presentDeleteResourceAlert: @MainActor (Resource.ID) -> Void
  internal var resourceMenuPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeleteAlertPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: @MainActor () -> AnyPublisher<Void, Error>
  internal var copyFieldValue: @MainActor (ResourceFieldSpecification) -> AnyPublisher<Void, Error>
}

extension ResourceDetailsController: UIController {

  internal typealias Context = Resource.ID

  internal struct State: Equatable {
    internal var resource: Resource
    internal var passwordRevealAvailable: Bool
    internal var revealedFields: Set<Resource.FieldPath>
  }

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features =
      features
      .branch(
        scope: ResourceDetailsScope.self,
        context: context
      )
    let features: Features = features

    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    let diagnostics: OSDiagnostics = features.instance()
    let resourceController: ResourceController = try features.instance()
    let pasteboard: OSPasteboard = features.instance()
    let revealedFields: CurrentValueSubject<Set<Resource.FieldPath>, Never> = .init(.init())

    let resourceMenuPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceSharePresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceEditPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()

    func statePublisher() -> AnyPublisher<State, Error> {
      resourceController
        .state
        .asThrowingPublisher()
        .map { resource in
          revealedFields
            .map { revealedFields in
              State(
                resource: resource,
                passwordRevealAvailable: sessionConfiguration.passwordPreviewEnabled,
                revealedFields: revealedFields
              )
            }
        }
        .switchToLatest()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func toggleDecrypt(
      field: ResourceFieldSpecification
    ) -> AnyPublisher<String?, Error> {
      guard
        (field.name != "password" && field.name != "secret")
          || sessionConfiguration.passwordPreviewEnabled
      else {
        return Fail(error: Unavailable.error("Password preview disabled"))
          .eraseToAnyPublisher()
      }
      if revealedFields.value.contains(field.path) {
        return Just(nil)
          .eraseErrorType()
          .handleEvents(receiveOutput: { _ in
            revealedFields.value.remove(field.path)
          })
          .eraseToAnyPublisher()
      }
      else {
        return
          cancellables.executeAsyncWithPublisher {
            try await resourceController.fetchSecretIfNeeded()
            revealedFields.value.insert(field.path)
            return try await resourceController.state.value[keyPath: field.path].stringValue
          }
      }
    }

    func presentResourceMenu() {
      resourceMenuPresentationSubject.send(context)
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuPresentationSubject.eraseToAnyPublisher()
    }

    func copyField(
      _ field: ResourceFieldSpecification
    ) -> AnyPublisher<Void, Error> {
      return cancellables.executeAsyncWithPublisher {
        let resource: Resource = try await resourceController.state.value
        if resource.secretContains(field.path) {
          try await resourceController.fetchSecretIfNeeded()
          try await pasteboard.put(
            resourceController.state.value[keyPath: field.path].stringValue
          )
        }
        else {
          pasteboard.put(
            resource[keyPath: field.path].stringValue
          )
        }
      }
    }

    func presentResourceShare(
      resourceID: Resource.ID
    ) {
      resourceSharePresentationSubject.send(resourceID)
    }

    func resourceSharePresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceSharePresentationSubject.eraseToAnyPublisher()
    }

    func presentResourceEdit(resourceID: Resource.ID) {
      resourceEditPresentationSubject.send(resourceID)
    }

    func resourceEditPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceEditPresentationSubject.eraseToAnyPublisher()
    }

    func presentDeleteResourceAlert(resourceID: Resource.ID) {
      resourceDeleteAlertPresentationSubject.send(resourceID)
    }

    func resourceDeleteAlertPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDeleteAlertPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeletionPublisher() -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        try await resourceController.delete()
      }
    }

    return Self(
      statePublisher: statePublisher,
      toggleDecrypt: toggleDecrypt(field:),
      presentResourceMenu: presentResourceMenu,
      presentResourceShare: presentResourceShare(resourceID:),
      presentResourceEdit: presentResourceEdit(resourceID:),
      resourceSharePresentationPublisher: resourceSharePresentationPublisher,
      resourceEditPresentationPublisher: resourceEditPresentationPublisher,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher,
      copyFieldValue: copyField(_:)
    )
  }
}
