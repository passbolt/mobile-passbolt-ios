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

public struct ResourceEditController {

  internal var createsNewResource: Bool
  internal var resourcePropertiesPublisher: @MainActor () -> AnyPublisher<Array<ResourceProperty>, Error>
  internal var fieldValuePublisher: @MainActor (ResourceField) -> AnyPublisher<Validated<String>, Never>
  internal var passwordEntropyPublisher: @MainActor () -> AnyPublisher<Entropy, Never>
  internal var sendForm: @MainActor () -> AnyPublisher<Void, Error>
  internal var setValue: @MainActor (String, ResourceField) -> AnyPublisher<Void, Error>
  internal var generatePassword: @MainActor () -> Void
  internal var presentExitConfirmation: @MainActor () -> Void
  internal var exitConfirmationPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var cleanup: @MainActor () -> Void
}

extension ResourceEditController {

  public enum EditingContext {
    case new(in: Folder.ID?)
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
    let diagnostics: Diagnostics = try await features.instance()
    let resources: Resources = try await features.instance()
    let resourceForm: ResourceEditForm = try await features.instance()
    let randomGenerator: RandomStringGenerator = try await features.instance()

    let resourcePropertiesSubject: CurrentValueSubject<Array<ResourceProperty>, Error> = .init([])
    let exitConfirmationPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    let createsNewResource: Bool
    switch context.editing {
    case let .existing(resourceID):
      createsNewResource = false
      await resourceForm
        .editResource(resourceID)
        .sink(
          receiveCompletion: { completion in
            cancellables.executeOnFeaturesActor {
              try await features.unload(ResourceEditForm.self)
            }
            guard case let .failure(error) = completion else { return }

            resourcePropertiesSubject.send(completion: .failure(error))
          },
          receiveValue: { /* NOP */  }
        )
        .store(in: cancellables)

    case let .new(in: enclosingFolder):
      createsNewResource = true
      resourceForm.setEnclosingFolder(enclosingFolder)
    }

    resourceForm
      .resourceTypePublisher()
      .map(\.properties)
      .sink(
        receiveCompletion: { completion in
          cancellables.executeOnFeaturesActor {
            try await features.unload(ResourceEditForm.self)
          }
          resourcePropertiesSubject.send(completion: completion)
        },
        receiveValue: { properties in
          resourcePropertiesSubject.send(properties)
        }
      )
      .store(in: cancellables)

    func resourcePropertiesPublisher() -> AnyPublisher<Array<ResourceProperty>, Error> {
      resourcePropertiesSubject
        .eraseToAnyPublisher()
    }

    func fieldValuePublisher(field: ResourceField) -> AnyPublisher<Validated<String>, Never> {
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
      for field: ResourceField
    ) -> AnyPublisher<Void, Error> {
      resourcePropertiesPublisher()
        .map { properties -> AnyPublisher<Void, Error> in
          guard let property: ResourceProperty = properties.first(where: { $0.field == field })
          else {
            return Fail(error: TheErrorLegacy.invalidOrMissingResourceType())
              .eraseToAnyPublisher()
          }

          return
            resourceForm
            .setFieldValue(.init(fromString: value, forType: property.type), field)
        }
        .switchToLatest()
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
      cancellables.executeOnAccountSessionActorWithPublisher {
        resourceForm
          .sendForm()
          .map { resourceID -> AnyPublisher<Resource.ID, Error> in
            resources
              .refreshIfNeeded()
              .map { resourceID }
              .eraseToAnyPublisher()
          }
          .switchToLatest()
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
        .setFieldValue(.string(password), .password)
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
      cancellables.executeOnFeaturesActor {
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
