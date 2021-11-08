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
import CommonDataModels
import Resources
import UIComponents

internal struct ResourceMenuController {

  internal var availableActionsPublisher: () -> AnyPublisher<Array<Action>, Never>
  internal var resourceDetailsPublisher: () -> AnyPublisher<ResourceDetailsController.ResourceDetails, TheError>
  internal var performAction: (Action) -> AnyPublisher<Void, TheError>
}

extension ResourceMenuController {

  internal enum Action: CaseIterable {
    case openURL
    case copyURL
    case copyPassword
    case copyUsername
    case copyDescription
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
    showEdit: (Resource.ID) -> Void,
    showDeleteAlert: (Resource.ID) -> Void
  )

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let linkOpener: LinkOpener = features.instance()
    let resources: Resources = features.instance()
    let pasteboard: Pasteboard = features.instance()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsController.ResourceDetails?, TheError> = .init(nil)

    resources
      .resourceDetailsPublisher(context.resourceID)
      .map(ResourceDetailsController.ResourceDetails.from(detailsViewResource:))
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

    func availableActionsPublisher() -> AnyPublisher<Array<Action>, Never> {
      currentDetailsSubject
        .removeDuplicates()
        .compactMap { resourceDetails -> Array<Action>? in
          guard let resourceDetails = resourceDetails
          else { return nil }

          return Action
            .allCases
            .filter({ action in
              switch action {
              case .openURL, .copyURL:
                return resourceDetails.properties.contains(where: { property in
                  if case .uri = property.field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyPassword:
                return resourceDetails.properties.contains(where: { property in
                  if case .password = property.field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyUsername:
                return resourceDetails.properties.contains(where: { property in
                  if case .username = property.field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyDescription:
                return resourceDetails.properties.contains(where: { property in
                  if case .description = property.field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .edit:
                return [
                  .owner,
                  .write,
                ]
                .contains(resourceDetails.permission)

              case .delete:
                return [
                  .owner,
                  .write,
                ]
                .contains(resourceDetails.permission)
              }
            }
            )
        }
        .replaceError(with: [])
        .eraseToAnyPublisher()
    }

    func resourceDetailsPublisher() -> AnyPublisher<ResourceDetailsController.ResourceDetails, TheError> {
      currentDetailsSubject
        .filterMapOptional()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func openURLAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
            let property: ResourceProperty = resourceDetails
              .properties
              .first(where: { $0.field == .username })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<Void, TheError> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  guard let url: URL = URL(string: secret)
                  else {
                    return Fail<Void, TheError>(error: .invalidResourceData())
                      .eraseToAnyPublisher()
                  }

                  return
                    linkOpener
                    .openLink(url)
                    .map { opened -> AnyPublisher<Void, TheError> in
                      if opened {
                        return Just(Void())
                          .setFailureType(to: TheError.self)
                          .eraseToAnyPublisher()
                      }
                      else {
                        return Fail<Void, TheError>(error: .failedToOpenURL())
                          .eraseToAnyPublisher()
                      }
                    }
                    .switchToLatest()
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just(Void())
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheError.invalidResourceSecret())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.url {
            guard let url: URL = URL(string: value)
            else {
              return Fail<Void, TheError>(error: .invalidResourceData())
                .eraseToAnyPublisher()
            }

            return
              linkOpener
              .openLink(url)
              .map { opened -> AnyPublisher<Void, TheError> in
                if opened {
                  return Just(Void())
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail<Void, TheError>(error: .failedToOpenURL())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
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

    func copyURLAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
            let property: ResourceProperty = resourceDetails
              .properties
              .first(where: { $0.field == .uri })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheError> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheError.invalidResourceSecret())
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
              .setFailureType(to: TheError.self)
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

    func copyPasswordAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
            let property: ResourceProperty = resourceDetails
              .properties
              .first(where: { $0.field == .password })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheError> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheError.invalidResourceSecret())
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

    func copyUsernameAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
            let property: ResourceProperty = resourceDetails
              .properties
              .first(where: { $0.field == .username })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheError> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheError.invalidResourceSecret())
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
              .setFailureType(to: TheError.self)
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

    func copyDescriptionAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
            let property: ResourceProperty = resourceDetails
              .properties
              .first(where: { $0.field == .description })
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return
              resources
              .loadResourceSecret(resourceDetails.id)
              .map { resourceSecret -> AnyPublisher<String, TheError> in
                if let secret: String = resourceSecret[dynamicMember: property.field.rawValue] {
                  return Just(secret)
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else if !property.required {
                  return Just("")
                    .setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail(error: TheError.invalidResourceSecret())
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
              .setFailureType(to: TheError.self)
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

    func editAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard let resourceDetails = resourceDetails
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard [.owner, .write].contains(resourceDetails.permission)
          else {
            return Fail<Void, TheError>(error: .permissionRequired())
              .eraseToAnyPublisher()
          }

          return Just(context.showEdit(resourceDetails.id))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func deleteAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard let resourceDetails = resourceDetails
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard [.owner, .write].contains(resourceDetails.permission)
          else {
            return Fail<Void, TheError>(error: .permissionRequired())
              .eraseToAnyPublisher()
          }

          return Just(context.showDeleteAlert(resourceDetails.id))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func perform(action: Action) -> AnyPublisher<Void, TheError> {
      switch action {
      case .openURL:
        return openURLAction()
      case .copyURL:
        return copyURLAction()
      case .copyPassword:
        return copyPasswordAction()
      case .copyUsername:
        return copyUsernameAction()
      case .copyDescription:
        return copyDescriptionAction()
      case .edit:
        return editAction()
      case .delete:
        return deleteAction()
      }
    }

    return Self(
      availableActionsPublisher: availableActionsPublisher,
      resourceDetailsPublisher: resourceDetailsPublisher,
      performAction: perform(action:)
    )
  }
}
