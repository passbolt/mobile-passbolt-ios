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
  }
}

extension ResourceMenuController {

  internal enum Source {
    case resourceList
    case resourceDetails
  }
}

extension ResourceMenuController: UIController {

  internal typealias Context = Resource.ID

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
      .resourceDetailsPublisher(context)
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
                return resourceDetails.fields.contains(where: { field in
                  if case .uri = field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyPassword:
                return resourceDetails.fields.contains(where: { field in
                  if case .password = field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyUsername:
                return resourceDetails.fields.contains(where: { field in
                  if case .username = field {
                    return true
                  }
                  else {
                    return false
                  }
                })

              case .copyDescription:
                return resourceDetails.fields.contains(where: { field in
                  if case .description = field {
                    return true
                  }
                  else {
                    return false
                  }
                })
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

          guard let url: URL = URL(string: urlString)
          else {
            return Fail<Void, TheError>(error: .invalidResourceData())
              .eraseToAnyPublisher()
          }

          return linkOpener
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
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyURLAction() -> AnyPublisher<Void, TheError> {
      currentDetailsSubject
        .first()
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
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
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard
            let resourceDetails = resourceDetails,
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
        .map { resourceDetails -> AnyPublisher<Void, TheError> in
          guard let resourceDetails = resourceDetails
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

  #warning("This is similar to ResourceDetailsController code, it might be unified to avoid duplicates")
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
      }
    }

    return Self(
      availableActionsPublisher: availableActionsPublisher,
      resourceDetailsPublisher: resourceDetailsPublisher,
      performAction: perform(action:)
    )
  }
}
