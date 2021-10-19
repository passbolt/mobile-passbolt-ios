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
import Resources
import UIComponents

internal struct ResourceDetailsController {

  internal var resourceDetailsWithConfigPublisher: () -> AnyPublisher<ResourceDetailsWithConfig, TheError>
  internal var toggleDecrypt: (ResourceDetails.Field) -> AnyPublisher<String?, TheError>
  internal var presentResourceMenu: () -> Void
  internal var presentDeleteResourceAlert: (Resource.ID) -> Void
  internal var resourceMenuPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeleteAlertPresentationPublisher: () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: (Resource.ID) -> AnyPublisher<Never, TheError>
  internal var copyFieldValue: (ResourceDetails.Field) -> AnyPublisher<Void, TheError>
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
    var revealedFields: Set<ResourceDetails.Field> = .init()

    let resourceMenuPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsWithConfig?, TheError> = .init(nil)

      resources.resourceDetailsPublisher(context)
        .map {
          let resourceDetails: ResourceDetailsController.ResourceDetails = .from(detailsViewResource: $0)
          let previewPassword: FeatureConfig.PreviewPassword = featureConfig.configuration()
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

    func resourceDetailsWithConfigPublisher() -> AnyPublisher<ResourceDetailsWithConfig, TheError> {
      currentDetailsSubject
        .filterMapOptional()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func toggleDecrypt(field: ResourceDetails.Field) -> AnyPublisher<String?, TheError> {
      lock.lock()
      defer { lock.unlock() }

      if revealedFields.contains(field) {
        return Just(nil)
        .setFailureType(to: TheError.self)
        .handleEvents(receiveOutput: { _ in
          lock.lock()
          revealedFields.remove(field)
          lock.unlock()
        })
        .eraseToAnyPublisher()
      }
      else {
        return resources.loadResourceSecret(context)
          .map { resourceSecret -> AnyPublisher<String?, TheError> in
            guard let secret: String = resourceSecret[dynamicMember: field.name().rawValue]
            else { return Fail<String?, TheError>(error: TheError.invalidResourceSecret()).eraseToAnyPublisher() }

            return Just(secret)
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()
          }
          .switchToLatest()
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

    func copyURLAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { details -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = details?.resourceDetails,
            resourceDetails.fields.contains(where: { field in
              if case .uri = field {
                return true
              }
              else {
                return false
              }
            })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard let urlString: String = resourceDetails.url
          else {
            return Fail<Void, TheError>(error: .missingResourceData())
              .eraseToAnyPublisher()
          }

          return Just(Void())
            .setFailureType(to: TheError.self)
            .handleEvents(receiveOutput: { _ in
              pasteboard.put(urlString)
            })
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyPasswordAction() -> AnyPublisher<Void, TheError> {
      resources
        .loadResourceSecret(context)
        .map { resourceSecret -> AnyPublisher<String, TheError> in
          guard let secret: String = resourceSecret.password
          else {
            return Fail(
              error: TheError.invalidResourceSecret()
            )
            .eraseToAnyPublisher()
          }
          return Just(secret)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { password in
          pasteboard.put(password)
        })
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    func copyUsernameAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { details -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = details?.resourceDetails,
            resourceDetails.fields.contains(where: { field in
              if case .username = field {
                return true
              }
              else {
                return false
              }
            })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard let username: String = resourceDetails.username
          else {
            return Fail<Void, TheError>(error: .missingResourceData())
              .eraseToAnyPublisher()
          }

          return Just(Void())
            .setFailureType(to: TheError.self)
            .handleEvents(receiveOutput: { _ in
              pasteboard.put(username)
            })
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyDescriptionAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { details -> AnyPublisher<Void, TheError> in
          guard let resourceDetails = details?.resourceDetails
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if resourceDetails.fields.contains(where: { field in
            guard case let .description(_, encrypted, _) = field
            else { return false }
            return encrypted
          }) {
            return resources
              .loadResourceSecret(context)
              .map { resourceSecret -> AnyPublisher<String, TheError> in
                guard let secret: String = resourceSecret.description
                else {
                  return Fail(
                    error: TheError.invalidResourceSecret()
                  )
                    .eraseToAnyPublisher()
                }
                return Just(secret)
                  .setFailureType(to: TheError.self)
                  .eraseToAnyPublisher()
              }
              .switchToLatest()
              .handleEvents(receiveOutput: { password in
                pasteboard.put(password)
              })
              .mapToVoid()
              .eraseToAnyPublisher()
          }
          else if let description: String = resourceDetails.description {
            return Just(Void())
              .setFailureType(to: TheError.self)
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(description)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(
              error: .missingResourceData()
            )
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    #warning("This is similar to ResourceMenuController code, it might be unified to avoid duplicates")
    func copyField(
      _ field: ResourceDetails.Field
    ) -> AnyPublisher<Void, TheError> {
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

    func presentDeleteResourceAlert(resourceID: Resource.ID) {
      resourceDeleteAlertPresentationSubject.send(resourceID)
    }

    func resourceDeleteAlertPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDeleteAlertPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeletionPublisher(resourceID: Resource.ID) -> AnyPublisher<Never, TheError> {
      resources.deleteResource(resourceID)
        .map { resources.refreshIfNeeded() }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      resourceDetailsWithConfigPublisher: resourceDetailsWithConfigPublisher,
      toggleDecrypt: toggleDecrypt(field:),
      presentResourceMenu: presentResourceMenu,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher(resourceID:),
      copyFieldValue: copyField(_:)
    )
  }
}
