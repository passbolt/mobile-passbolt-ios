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
import Crypto
import Features
import NetworkClient
import Users

public struct ResourceCreateForm {

  // initial version supports only one type of resource type, so there is no method to change it
  public var resourceTypePublisher: () -> AnyPublisher<ResourceType, TheError>
  // since currently the only field value is String we are not allowing other value types
  public var setFieldValue: (String, String) -> AnyPublisher<Void, TheError>
  // prepare publisher for given field, publisher will complete when field will be no longer available
  public var fieldValuePublisher: (String) -> AnyPublisher<Validated<String>, Never>
  // send the form and create resource on server
  public var createResource: () -> AnyPublisher<Resource.ID, TheError>
  public var featureUnload: () -> Bool
}

extension ResourceCreateForm: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSession: AccountSession = features.instance()
    let database: AccountDatabase = features.instance()
    let networkClient: NetworkClient = features.instance()
    let userPGPMessages: UserPGPMessages = features.instance()

    let resourceTypeSubject: CurrentValueSubject<ResourceType?, TheError> = .init(nil)
    let resourceTypePublisher: AnyPublisher<ResourceType, TheError> = resourceTypeSubject.filterMapOptional().eraseToAnyPublisher()
    let formValuesSubject: CurrentValueSubject<Dictionary<String, Validated<String>>, Never> = .init(.init())

    database
      .fetchResourcesTypesOperation()
      .map { resourceTypes -> AnyPublisher<ResourceType, TheError> in
        // in initial version we are supporting only one type of resource for being created
        if let resourceType: ResourceType = resourceTypes.first(where: \.isDefault) {
          return Just(resourceType)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        else {
          return Fail(error: .invalidOrMissingResourceType())
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resourceTypeSubject.send(completion: .failure(error))
        },
        receiveValue: { resourceType in
          // remove fields that are no longer in resource
          let removedFieldNames: Array<String> = formValuesSubject.value.keys.filter { key in
            !resourceType.fields.contains(where: { $0.name == key })
          }
          for removedFieldName in removedFieldNames {
            formValuesSubject.value.removeValue(forKey: removedFieldName)
          }

          // add new fields (if any) and validate again existing ones
          for field in resourceType.fields {
            let fieldValue: String = formValuesSubject.value[field.name]?.value ?? ""
            formValuesSubject.value[field.name] = fieldValidator(for: field).validate(fieldValue)
          }
          resourceTypeSubject.send(resourceType)
        }
      )
      .store(in: cancellables)

    func fieldValidator(
      for field: ResourceField
    ) -> Validator<String> {
      zip(
        {
          if field.required {
            return .nonEmpty(errorLocalizationKey: "resource.form.field.error.empty", bundle: .commons)
          }
          else {
            return .alwaysValid
          }
        }(),
        // even if there is no requirement for max length we are limiting it with
        // some high value to prevent too big values
        .maxLength(
          UInt(field.maxLength ?? 10000),
          errorLocalizationKey: "resource.form.field.error.max.length",
          bundle: .commons
        )
      )
    }

    func setFieldValue(
      _ value: String,
      fieldName: String
    ) -> AnyPublisher<Void, TheError> {
      resourceTypePublisher
        .map { resourceType -> AnyPublisher<Validated<String>, TheError> in
          if let field: ResourceField = resourceType.fields.first(where: { $0.name == fieldName }) {
            return Just(fieldValidator(for: field).validate(value))
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: .invalidOrMissingResourceType())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { validatedValue in
          formValuesSubject.value[fieldName] = validatedValue
        })
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    func fieldValuePublisher(
      fieldName: String
    ) -> AnyPublisher<Validated<String>, Never> {
      formValuesSubject
        .map { formFields -> AnyPublisher<Validated<String>, Never> in
          if let fieldValue: Validated<String> = formFields[fieldName] {
            return Just(fieldValue)
              .eraseToAnyPublisher()
          }
          else {
            return Empty(completeImmediately: true)
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .removeDuplicates { lhs, rhs in
          lhs.value == rhs.value && lhs.isValid == rhs.isValid
        }
        .eraseToAnyPublisher()
    }

    func createResource() -> AnyPublisher<Resource.ID, TheError> {
      Publishers.CombineLatest(
        resourceTypePublisher,
        formValuesSubject
          .setFailureType(to: TheError.self)
      )
        .first()
        .map { resourceType, validatedFieldValues -> AnyPublisher<(fieldValues: Dictionary<String, String>, encodedSecret: String), TheError> in
          var fieldValues: Dictionary<String, String> = .init()
          var secretFieldValues: Dictionary<String, String> = .init()

          for (key, validatedValue) in validatedFieldValues {
            guard let field: ResourceField = resourceType.fields.first(where: { $0.name == key })
            else {
              assertionFailure("Trying to use form value that is not associated with any resource fields")
              continue
            }
            guard validatedValue.isValid
            else {
              return Fail(error: .validationError("resource.form.error.invalid", bundle: .commons))
                .eraseToAnyPublisher()
            }
            if field.encrypted {
              secretFieldValues[key] = validatedValue.value
            }
            else {
              fieldValues[key] = validatedValue.value
            }
          }

          let encodedSecretFields: String = secretFieldValues
            .map { field -> String in
              "\"\(field.key)\":\"\(field.value)\""
            }
            .joined(separator: ",")
          let encodedSecret: String = "{\(encodedSecretFields)}"

          return Just((fieldValues: fieldValues, encodedSecret: encodedSecret))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { (fieldValues, encodedSecret) -> AnyPublisher<Resource.ID, TheError> in
          resourceTypeSubject
            .first()
            .compactMap(\.?.id)
            .map { resourceTypeID -> AnyPublisher<Resource.ID, TheError> in
              guard let name: String = fieldValues["name"]
              else {
                return Fail(
                  error: .invalidOrMissingResourceType()
                )
                .eraseToAnyPublisher()
              }

              return accountSession
                .statePublisher()
                .first()
                .map { sessionState -> AnyPublisher<ArmoredPGPMessage, TheError> in
                  switch sessionState {
                  case let .authorized(account), let .authorizedMFARequired(account, _):
                    return userPGPMessages
                      .encryptMessageForUser(.init(rawValue: account.userID.rawValue), encodedSecret)
                      .eraseToAnyPublisher()

                  case .authorizationRequired, .none:
                    return Fail(error: .authorizationRequired())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .map { encryptedSecret in
                  networkClient
                    .createResourceRequest
                    .make(
                      using: .init(
                        resourceTypeID: resourceTypeID.rawValue,
                        name: name,
                        username: fieldValues["username"],
                        url: fieldValues["uri"],
                        description: fieldValues["description"],
                        secretData: encryptedSecret.rawValue
                      )
                    )
                    .map { response -> Resource.ID in
                      .init(rawValue: response.body.resourceID)
                    }
                    .eraseToAnyPublisher()
                }
                .switchToLatest()
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func featureUnload() -> Bool {
      true
    }

    return Self(
      resourceTypePublisher: { resourceTypePublisher },
      setFieldValue: setFieldValue(_:fieldName:),
      fieldValuePublisher: fieldValuePublisher(fieldName:),
      createResource: createResource,
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension ResourceCreateForm {

  public static var placeholder: ResourceCreateForm {
    Self(
      resourceTypePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setFieldValue: Commons.placeholder("You have to provide mocks for used methods"),
      fieldValuePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      createResource: Commons.placeholder("You have to provide mocks for used methods"),
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
