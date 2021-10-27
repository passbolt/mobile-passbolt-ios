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
import UIComponents
import Resources

internal struct ResourceCreateController {

  internal var resourceFieldsPublisher: () -> AnyPublisher<Array<Field>, TheError>
  internal var fieldValuePublisher: (String) -> AnyPublisher<Validated<String>, Never>
  internal var passwordEntropyPublisher: () -> AnyPublisher<Entropy, Never>
  internal var createResource: () -> AnyPublisher<Void, TheError>
  internal var setValue: (String, String) -> AnyPublisher<Void, TheError>
  internal var generatePassword: () -> Void
  internal var cleanup: () -> Void
}

extension ResourceCreateController {

  internal typealias FieldName = Tagged<String, ResourceCreateController>
}

extension ResourceCreateController {

  #warning("PAS-409 Unify dynamic fields")
  internal enum Field: Comparable, Hashable {

    case name(required: Bool, encrypted: Bool, maxLength: Int?)
    case username(required: Bool, encrypted: Bool, maxLength: Int?)
    case password(required: Bool, encrypted: Bool, maxLength: Int?)
    case uri(required: Bool, encrypted: Bool, maxLength: Int?)
    case description(required: Bool, encrypted: Bool, maxLength: Int?)

    fileprivate static func from(resourceField: ResourceField) -> Field? {
      switch resourceField {
      case let .string("name", required, encrypted, maxLength):
        return .name(required: required, encrypted: encrypted, maxLength: maxLength)
      case let .string("username", required, encrypted, maxLength):
        return .username(required: required, encrypted: encrypted, maxLength: maxLength)
      case let .string("password", required, encrypted, maxLength),
           let .string("secret", required, encrypted, maxLength):
        return .password(required: required, encrypted: encrypted, maxLength: maxLength)
      case let .string("uri", required, encrypted, maxLength):
        return .uri(required: required, encrypted: encrypted, maxLength: maxLength)
      case let .string("description", required, encrypted, maxLength):
        return .description(required: required, encrypted: encrypted, maxLength: maxLength)
      case _:
        return nil
      }
    }

    internal func name() -> FieldName {
      switch self {
      case .name:
        return "name"
      case .username:
        return "username"
      case .password:
        return "password"
      case .uri:
        return "uri"
      case .description:
        return "description"
      }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (name, _):
        return true
      case (.uri, .username), (.uri, .password), (.uri, .description):
        return true
      case (.username, .password), (.username, .description):
        return true
      case (.password, .description):
        return true
      case (.description, _):
        return false
      case _:
        return false
      }
    }
  }
}

extension ResourceCreateController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {

    let resources: Resources = features.instance()
    let resourceForm: ResourceCreateForm = features.instance()
    let randomGenerator: RandomStringGenerator = features.instance()

    func resourceFieldsPublisher() -> AnyPublisher<Array<Field>, TheError> {
      resourceForm.resourceTypePublisher()
        .map { resourceType in
          resourceType.fields.compactMap { resourceField in
            Field.from(resourceField: resourceField)
          }
        }
        .eraseToAnyPublisher()
    }

    func fieldValuePublisher(fieldName: String) -> AnyPublisher<Validated<String>, Never> {
      resourceForm.fieldValuePublisher(fieldName)
    }

    func setValue(_ value: String, for field: String) -> AnyPublisher<Void, TheError> {
      resourceForm.setFieldValue(value, field)
    }

    func passwordEntropyPublisher() -> AnyPublisher<Entropy, Never> {
      resourceForm.fieldValuePublisher("password")
        .map { field in
          randomGenerator.entropy(
            field.value,
            CharacterSets.all
          )
        }
        .eraseToAnyPublisher()
    }

    func createResource() -> AnyPublisher<Void, TheError> {
      resourceForm.createResource()
        .mapToVoid()
        .map { _ -> AnyPublisher<Void, TheError> in
          resources.refreshIfNeeded()
            .mapToVoid()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveCompletion: { [weak features] completion in
          guard case .finished = completion
          else { return }

          features?.unload(ResourceCreateForm.self)
        })
        .eraseToAnyPublisher()
    }

    func generatePassword() {
      let password: String = randomGenerator.generate(
        CharacterSets.all,
        18,
        Entropy.veryStrongPassword
      )

      resourceForm.setFieldValue(password, "password")
        .sinkDrop()
        .store(in: cancellables)
    }

    func cleanup() {
      features.unload(ResourceCreateForm.self)
    }

    return Self(
      resourceFieldsPublisher: resourceFieldsPublisher,
      fieldValuePublisher: fieldValuePublisher,
      passwordEntropyPublisher: passwordEntropyPublisher,
      createResource: createResource,
      setValue: setValue(_:for:),
      generatePassword: generatePassword,
      cleanup: cleanup
    )
  }
}
