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

  internal var availableActionsPublisher: () -> AnyPublisher<Array<ResourceMenuController.Action>, Never>
  internal var resourceDetailsPublisher: () -> AnyPublisher<ResourceDetailsController.ResourceDetails, TheError>
  internal var resourceSecretPublisher: () -> AnyPublisher<String, TheError>
  internal var copyURLPublisher: () -> AnyPublisher<Void, Never>
  internal var openURLPublisher: () -> AnyPublisher<Bool, Never>
  internal var performAction: (ResourceMenuController.Action) -> Void
}

extension ResourceMenuController {

  internal enum Action {
    case openURL
    case copyURL
    case copyPassword
  }
}

extension ResourceMenuController {

  internal enum Source {
    case resourceList
    case resourceDetails
  }
}

extension ResourceMenuController: UIController {

  internal typealias Context = (id: Resource.ID, source: Source)

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables) -> Self {

    let linkOpener: LinkOpener = features.instance()
    let resources: Resources = features.instance()
    let pasteboard: Pasteboard = features.instance()

    let openUrlSubject: PassthroughSubject<Void, Never> = .init()
    let copyUrlSubject: PassthroughSubject<Void, Never> = .init()
    let secretCopySubject: PassthroughSubject<Void, Never> = .init()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsController.ResourceDetails?, TheError> = .init(nil)

      resources.resourceDetailsPublisher(context.id)
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

    func availableActionsPublisher() -> AnyPublisher<Array<ResourceMenuController.Action>, Never> {
      switch context.source {
      case .resourceList:
        return Just([.openURL, .copyURL, .copyPassword]).eraseToAnyPublisher()
      case .resourceDetails:
        return Just([.copyPassword]).eraseToAnyPublisher()
      }
    }

    func resourceDetailsPublisher() -> AnyPublisher<ResourceDetailsController.ResourceDetails, TheError> {
      currentDetailsSubject
        .filterMapOptional()
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    func resourceSecretPublisher() -> AnyPublisher<String, TheError> {
      secretCopySubject
        .map {
          resources.loadResourceSecret(context.id)
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
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { output in
          pasteboard.put(output)
        })
        .eraseToAnyPublisher()
    }

    func copyURLPublisher() -> AnyPublisher<Void, Never> {
      copyUrlSubject
        .map {
          currentDetailsSubject
            .replaceError(with: nil)
            .compactMap { $0?.url }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { url in
          pasteboard.put(url)
        }
        .eraseToAnyPublisher()
    }

    func openURLPublisher() -> AnyPublisher<Bool, Never> {
      openUrlSubject.map {
        currentDetailsSubject
          .replaceError(with: nil)
          .map { resourceDetails -> URL? in
            guard
              let resourceDetails = resourceDetails,
              let urlString: String = resourceDetails.url,
              let url: URL = URL(string: urlString)
            else { return nil }

            return url
          }
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .map { url -> AnyPublisher<Bool, Never> in
        guard let url: URL = url
        else { return Just(false).eraseToAnyPublisher() }

        return linkOpener.openLink(url)
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func perform(action: Action) {
      switch action {
      case .copyPassword:
        secretCopySubject.send()
      case .openURL:
        openUrlSubject.send()
      case .copyURL:
        copyUrlSubject.send()
      }
    }

    return Self(
      availableActionsPublisher: availableActionsPublisher,
      resourceDetailsPublisher: resourceDetailsPublisher,
      resourceSecretPublisher: resourceSecretPublisher,
      copyURLPublisher: copyURLPublisher,
      openURLPublisher: openURLPublisher,
      performAction: perform(action:)
    )
  }
}
