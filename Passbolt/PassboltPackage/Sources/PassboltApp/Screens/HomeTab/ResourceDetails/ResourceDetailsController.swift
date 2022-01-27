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
import Resources
import UIComponents

internal struct ResourceDetailsController {

  internal var resourceDetailsWithConfigPublisher: () -> AnyPublisher<ResourceDetailsWithConfig, TheErrorLegacy>
  internal var toggleDecrypt: (ResourceField) -> AnyPublisher<String?, TheErrorLegacy>
  internal var presentResourceMenu: () -> Void
  internal var presentResourceEdit: (Resource.ID) -> Void
  internal var resourceEditPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var presentDeleteResourceAlert: (Resource.ID) -> Void
  internal var resourceMenuPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeleteAlertPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: (Resource.ID) -> AnyPublisher<Void, TheErrorLegacy>
  internal var copyFieldValue: (ResourceField) -> AnyPublisher<Void, TheErrorLegacy>
}

extension ResourceDetailsController {

  internal struct ResourceDetailsWithConfig: Equatable {

    internal var resourceDetails: ResourceDetailsController.ResourceDetails
    internal var revealPasswordEnabled: Bool
  }
}

extension ResourceDetailsController: UIController {

  internal typealias Context = Resource.ID

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {

    let resources: Resources = features.instance()
    let pasteboard: Pasteboard = features.instance()
    let featureConfig: FeatureConfig = features.instance()

    let lock: NSRecursiveLock = .init()
    var revealedFields: Set<ResourceField> = .init()

    let resourceMenuPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceEditPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsWithConfig?, TheErrorLegacy> = .init(nil)

    resources.resourceDetailsPublisher(context)
      .map {
        let resourceDetails: ResourceDetailsController.ResourceDetails = .from(detailsViewResource: $0)
        let previewPassword: FeatureFlags.PreviewPassword = featureConfig.configuration()
        let previewPasswordEnabled: Bool = {
          switch previewPassword {
          case .enabled:
            return true
          case .disabled:
            return false
          }
        }()

        return .init(
          resourceDetails: resourceDetails,
          revealPasswordEnabled: previewPasswordEnabled
        )
      }
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }

          currentDetailsSubject.send(completion: .failure(error))
        },
        receiveValue: { resourceDetails in
          currentDetailsSubject.send(resourceDetails)
        }
      )
      .store(in: cancellables)

    func resourceDetailsWithConfigPublisher() -> AnyPublisher<ResourceDetailsWithConfig, TheErrorLegacy> {
      currentDetailsSubject
        .filterMapOptional()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func toggleDecrypt(field: ResourceField) -> AnyPublisher<String?, TheErrorLegacy> {
      lock.lock()
      defer { lock.unlock() }

      if revealedFields.contains(field) {
        return Just(nil)
          .setFailureType(to: TheErrorLegacy.self)
          .handleEvents(receiveOutput: { _ in
            lock.lock()
            revealedFields.remove(field)
            lock.unlock()
          })
          .eraseToAnyPublisher()
      }
      else {
        return
          resources
          .loadResourceSecret(context)
          .map { resourceSecret -> String in
            resourceSecret[dynamicMember: field.rawValue] ?? ""
          }
          .handleEvents(receiveOutput: { _ in
            lock.lock()
            revealedFields.insert(field)
            lock.unlock()
          })
          .eraseToAnyPublisher()
      }
    }

    func presentResourceMenu() {
      resourceMenuPresentationSubject.send(context)
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuPresentationSubject.eraseToAnyPublisher()
    }

    func copyURLAction() -> AnyPublisher<Void, TheErrorLegacy> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, TheErrorLegacy> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let property: ResourceProperty = detailsWithConfig?.resourceDetails
              .properties
              .first(where: { $0.field == .uri })
          else {
            return Fail<Void, TheErrorLegacy>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheErrorLegacy> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheErrorLegacy.invalidResourceSecret())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .handleEvents(receiveOutput: { value in
                pasteboard.put(value)
              })
              .mapToVoid()
              .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.url {
            return Just(Void())
              .setFailureType(to: TheErrorLegacy.self)
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: .missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyPasswordAction() -> AnyPublisher<Void, TheErrorLegacy> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, TheErrorLegacy> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let property: ResourceProperty = detailsWithConfig?.resourceDetails
              .properties
              .first(where: { $0.field == .password })
          else {
            return Fail<Void, TheErrorLegacy>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheErrorLegacy> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheErrorLegacy.invalidResourceSecret())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .handleEvents(receiveOutput: { value in
                pasteboard.put(value)
              })
              .mapToVoid()
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: .missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyUsernameAction() -> AnyPublisher<Void, TheErrorLegacy> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, TheErrorLegacy> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let property: ResourceProperty = detailsWithConfig?.resourceDetails
              .properties
              .first(where: { $0.field == .username })
          else {
            return Fail<Void, TheErrorLegacy>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheErrorLegacy> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheErrorLegacy.invalidResourceSecret())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .handleEvents(receiveOutput: { value in
                pasteboard.put(value)
              })
              .mapToVoid()
              .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.username {
            return Just(Void())
              .setFailureType(to: TheErrorLegacy.self)
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: .missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyDescriptionAction() -> AnyPublisher<Void, TheErrorLegacy> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, TheErrorLegacy> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let property: ResourceProperty = detailsWithConfig?.resourceDetails
              .properties
              .first(where: { $0.field == .description })
          else {
            return Fail<Void, TheErrorLegacy>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheErrorLegacy> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheErrorLegacy.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheErrorLegacy.invalidResourceSecret())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .handleEvents(receiveOutput: { value in
                pasteboard.put(value)
              })
              .mapToVoid()
              .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.description {
            return Just(Void())
              .setFailureType(to: TheErrorLegacy.self)
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: .missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyField(
      _ field: ResourceField
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      switch field {
      case .uri:
        return copyURLAction()

      case .password:
        return copyPasswordAction()

      case .username:
        return copyUsernameAction()

      case .description:
        return copyDescriptionAction()

      case _:
        assertionFailure("Unhandled resource field - \(field)")
        return Fail(error: .invalidResourceData())
          .eraseToAnyPublisher()
      }
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

    func resourceDeletionPublisher(resourceID: Resource.ID) -> AnyPublisher<Void, TheErrorLegacy> {
      resources.deleteResource(resourceID)
        .map { resources.refreshIfNeeded() }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      resourceDetailsWithConfigPublisher: resourceDetailsWithConfigPublisher,
      toggleDecrypt: toggleDecrypt(field:),
      presentResourceMenu: presentResourceMenu,
      presentResourceEdit: presentResourceEdit(resourceID:),
      resourceEditPresentationPublisher: resourceEditPresentationPublisher,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher(resourceID:),
      copyFieldValue: copyField(_:)
    )
  }
}
