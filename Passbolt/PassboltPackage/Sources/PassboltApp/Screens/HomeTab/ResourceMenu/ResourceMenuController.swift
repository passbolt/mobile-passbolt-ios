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

internal struct ResourceMenuController {

  internal var availableActionsPublisher: @MainActor () -> AnyPublisher<Array<Action>, Never>
  internal var resourceDetailsPublisher: @MainActor () -> AnyPublisher<ResourceDetailsDSV, Error>
  internal var performAction: @MainActor (Action) -> AnyPublisher<Void, Error>
}

extension ResourceMenuController {

  internal enum Action: CaseIterable {
    case openURL
    case copyURL
    case copyUsername
    case copyPassword
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
    showEdit: @MainActor (Resource.ID) -> Void,
    showDeleteAlert: @MainActor (Resource.ID) -> Void
  )

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let linkOpener: LinkOpener = try await features.instance()
    let resources: Resources = try await features.instance()
    let pasteboard: Pasteboard = try await features.instance()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsDSV?, Error> = .init(
      nil
    )

    resources
      .resourceDetailsPublisher(context.resourceID)
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
        .compactMap { resourceDetails -> Array<Action>? in
          guard let resourceDetails = resourceDetails
          else { return nil }

          return Action
            .allCases
            .filter({ action in
              switch action {
              case .openURL, .copyURL:
                return resourceDetails.fields.contains(where: { field in
                  if case .uri = field.name {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyPassword:
                return resourceDetails.fields.contains(where: { field in
                  if case .password = field.name {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyUsername:
                return resourceDetails.fields.contains(where: { field in
                  if case .username = field.name {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyDescription:
                return resourceDetails.fields.contains(where: { field in
                  if case .description = field.name {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .edit:
                return resourceDetails.permissionType.canEdit

              case .delete:
                return resourceDetails.permissionType.canEdit
              }
            }
            )
        }
        .replaceError(with: [])
        .eraseToAnyPublisher()
    }

    func resourceDetailsPublisher() -> AnyPublisher<ResourceDetailsDSV, Error> {
      currentDetailsSubject
        .filterMapOptional()
        .eraseToAnyPublisher()
    }

    func openURLAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = resourceDetails,
            let field: ResourceFieldDSV = resourceDetails
              .fields
              .first(where: { $0.name == .username })
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeOnAccountSessionActorWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<Void, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    guard let url: URL = URL(string: secret)
                    else {
                      return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
                        .eraseToAnyPublisher()
                    }

                    return
                      linkOpener
                      .openLink(url)
                      .map { opened -> AnyPublisher<Void, Error> in
                        if opened {
                          return Just(Void())
                            .eraseErrorType()
                            .eraseToAnyPublisher()
                        }
                        else {
                          return Fail<Void, Error>(error: TheErrorLegacy.failedToOpenURL())
                            .eraseToAnyPublisher()
                        }
                      }
                      .switchToLatest()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just(Void())
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: TheErrorLegacy.invalidResourceSecret())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.url {
            guard let url: URL = URL(string: value)
            else {
              return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
                .eraseToAnyPublisher()
            }

            return
              linkOpener
              .openLink(url)
              .map { opened -> AnyPublisher<Void, Error> in
                if opened {
                  return Just(Void())
                    .eraseErrorType()
                    .eraseToAnyPublisher()
                }
                else {
                  return Fail<Void, Error>(error: TheErrorLegacy.failedToOpenURL())
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyURLAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = resourceDetails,
            let field: ResourceFieldDSV = resourceDetails
              .fields
              .first(where: { $0.name == .uri })
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeOnAccountSessionActorWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
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
            }
            .switchToLatest()
            .mapToVoid()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.url {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyPasswordAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = resourceDetails,
            let field: ResourceFieldDSV = resourceDetails
              .fields
              .first(where: { $0.name == .password })
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeOnAccountSessionActorWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
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
            }
            .switchToLatest()
            .mapToVoid()
            .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyUsernameAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = resourceDetails,
            let field: ResourceFieldDSV = resourceDetails
              .fields
              .first(where: { $0.name == .username })
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeOnAccountSessionActorWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
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
            }
            .switchToLatest()
            .mapToVoid()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.username {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyDescriptionAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = resourceDetails,
            let field: ResourceFieldDSV = resourceDetails
              .fields
              .first(where: { $0.name == .description })
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeOnAccountSessionActorWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
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
            }
            .switchToLatest()
            .mapToVoid()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.description {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.missingResourceData())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func editAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard let resourceDetails = resourceDetails
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard resourceDetails.permissionType.canEdit
          else {
            return Fail<Void, Error>(
              error: ResourcePermissionRequired.error()
            )
            .eraseToAnyPublisher()
          }

          return Just(context.showEdit(resourceDetails.id))
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func deleteAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, Error> in
          guard let resourceDetails = resourceDetails
          else {
            return Fail<Void, Error>(error: TheErrorLegacy.invalidResourceData())
              .eraseToAnyPublisher()
          }

          guard resourceDetails.permissionType.canEdit
          else {
            return Fail<Void, Error>(
              error: ResourcePermissionRequired.error()
            )
            .eraseToAnyPublisher()
          }

          return Just(context.showDeleteAlert(resourceDetails.id))
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func perform(action: Action) -> AnyPublisher<Void, Error> {
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
