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
import Crypto
import OSFeatures
import Resources
import SessionData
import UIComponents

public struct ResourceEditController {

  internal var createsNewResource: Bool
  internal var resourcePropertiesPublisher: @MainActor () -> AnyPublisher<Array<ResourceFieldDSV>, Error>
  internal var fieldValuePublisher: @MainActor (ResourceFieldNameDSV) -> AnyPublisher<Validated<String>, Never>
  internal var passwordEntropyPublisher: @MainActor () -> AnyPublisher<Entropy, Never>
  internal var sendForm: @MainActor () -> AnyPublisher<Void, Error>
  internal var setValue: @MainActor (String, ResourceFieldNameDSV) -> AnyPublisher<Void, Error>
  internal var generatePassword: @MainActor () -> Void
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var cleanup: @MainActor () -> Void
}

extension ResourceEditController {

  public enum EditingContext {
    case new(in: ResourceFolder.ID?, url: URLString?)
    case existing(Resource.ID)
  }
}

extension ResourceEditController: UIController {

  public typealias Context = (
    editing: EditingContext,
    completion: (Resource.ID) -> Void
  )

  public static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let sessionData: SessionData = try await features.instance()
    let resourceForm: ResourceEditForm = try await features.instance()
    let randomGenerator: RandomStringGenerator = try await features.instance()

    let resourcePropertiesSubject: CurrentValueSubject<Array<ResourceFieldDSV>, Error> = .init([])
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    let createsNewResource: Bool
    switch context.editing {
    case let .existing(resourceID):
      createsNewResource = false
      resourceForm
        .editResource(resourceID)
        .sink(
          receiveCompletion: { completion in
            cancellables.executeOnMainActor {
              try await features.unload(ResourceEditForm.self)
            }
            guard case let .failure(error) = completion else { return }

            resourcePropertiesSubject.send(completion: .failure(error))
          },
          receiveValue: { /* NOP */  }
        )
        .store(in: cancellables)

    case let .new(in: enclosingFolder, url):
      createsNewResource = true
      resourceForm.setEnclosingFolder(enclosingFolder)
      if let urlString: URLString = url {
        resourceForm
          .setFieldValue(urlString.rawValue, .uri)
          .sinkDrop()
          .store(in: cancellables)
      }
    }

    resourceForm
      .resourceTypePublisher()
      .map(\.fields)
      .sink(
        receiveCompletion: { completion in
          cancellables.executeOnMainActor {
            try await features.unload(ResourceEditForm.self)
          }
          resourcePropertiesSubject.send(completion: completion)
        },
        receiveValue: { properties in
          resourcePropertiesSubject.send(properties)
        }
      )
      .store(in: cancellables)

    func resourcePropertiesPublisher() -> AnyPublisher<Array<ResourceFieldDSV>, Error> {
      resourcePropertiesSubject
        .eraseToAnyPublisher()
    }

    func fieldValuePublisher(field: ResourceFieldNameDSV) -> AnyPublisher<Validated<String>, Never> {
      resourceForm
        .fieldValuePublisher(field)
        .map { validatedFieldValue -> Validated<String> in
          Validated<String>(
            value: validatedFieldValue.value.stringValue,
            errors: validatedFieldValue.errors
          )
        }
        .eraseToAnyPublisher()
    }

    func setValue(
      _ value: String,
      for fieldName: ResourceFieldNameDSV
    ) -> AnyPublisher<Void, Error> {
      resourceForm
        .setFieldValue(value, fieldName)
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }

    func passwordEntropyPublisher() -> AnyPublisher<Entropy, Never> {
      resourceForm
        .fieldValuePublisher(.password)
        .map { validated in
          randomGenerator.entropy(
            validated.value.stringValue,
            CharacterSets.all
          )
        }
        .eraseToAnyPublisher()
    }

    func sendForm() -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        resourceForm
          .sendForm()
          .asyncMap { resourceID -> Resource.ID in
            try await sessionData
              .refreshIfNeeded()
            return resourceID
          }
          .handleEvents(
            receiveOutput: { resourceID in
              context.completion(resourceID)
            },
            receiveCompletion: { completion in
              guard case .finished = completion
              else { return }

              cancellables.executeOnMainActor {
                cleanup()
              }
            }
          )
          .mapToVoid()
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func generatePassword() {
      let password: String = randomGenerator.generate(
        CharacterSets.all,
        18,
        Entropy.veryStrongPassword
      )

      resourceForm
        .setFieldValue(password, .password)
        .sinkDrop()
        .store(in: cancellables)
    }

    func presentExitConfirmation() {
      exitConfirmationPresentationSubject.send(true)
    }

    func exitConfirmationPresentationPublisher() -> AnyPublisher<Bool, Never> {
      exitConfirmationPresentationSubject.eraseToAnyPublisher()
    }

    func cleanup() {
      cancellables.executeOnMainActor {
        try await features.unload(ResourceEditForm.self)
      }
    }

    return Self(
      createsNewResource: createsNewResource,
      resourcePropertiesPublisher: resourcePropertiesPublisher,
      fieldValuePublisher: fieldValuePublisher,
      passwordEntropyPublisher: passwordEntropyPublisher,
      sendForm: sendForm,
      setValue: setValue(_:for:),
      generatePassword: generatePassword,
      presentExitConfirmation: presentExitConfirmation,
      exitConfirmationPresentationPublisher: exitConfirmationPresentationPublisher,
      cleanup: cleanup
    )
  }
}
