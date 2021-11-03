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
import Crypto
import Features
import NetworkClient
import Users

import class Foundation.JSONEncoder

public struct ResourceEditForm {

  // initial version supports only one type of resource type, so there is no method to change it
  public var resourceTypePublisher: () -> AnyPublisher<ResourceType, TheError>
  // since currently the only field value is String we are not allowing other value types
  public var setFieldValue: (ResourceFieldValue, ResourceField) -> AnyPublisher<Void, TheError>
  // prepare publisher for given field, publisher will complete when field will be no longer available
  public var fieldValuePublisher: (ResourceField) -> AnyPublisher<Validated<ResourceFieldValue>, Never>
  // send the form and create resource on server
  public var sendForm: () -> AnyPublisher<Resource.ID, TheError>
  public var featureUnload: () -> Bool
}

extension ResourceEditForm: Feature {

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
    let resourceTypePublisher: AnyPublisher<ResourceType, TheError> =
      resourceTypeSubject.filterMapOptional().eraseToAnyPublisher()
    let formValuesSubject: CurrentValueSubject<Dictionary<ResourceField, Validated<ResourceFieldValue>>, Never> =
      .init(.init())

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
          let removedFields: Array<ResourceField> = formValuesSubject.value.keys.filter { key in
            !resourceType.properties.contains(where: { $0.field == key })
          }
          for removedField in removedFields {
            formValuesSubject.value.removeValue(forKey: removedField)
          }

          // add new fields (if any) and validate again existing ones
          for property in resourceType.properties {
            let fieldValue: ResourceFieldValue =
              formValuesSubject.value[property.field]?.value
              ?? .init(defaultFor: property.type)
            formValuesSubject.value[property.field] =
              propertyValidator(for: property)
              .validate(fieldValue)
          }
          resourceTypeSubject.send(resourceType)
        }
      )
      .store(in: cancellables)

    func propertyValidator(
      for property: ResourceProperty
    ) -> Validator<ResourceFieldValue> {
      switch property.type {
      case .string:
        return zip(
          {
            if property.required {
              return .nonEmpty(errorLocalizationKey: "resource.form.field.error.empty", bundle: .commons)
            }
            else {
              return .alwaysValid
            }
          }(),
          // even if there is no requirement for max length we are limiting it with
          // some high value to prevent too big values
          .maxLength(
            UInt(property.maxLength ?? 10000),
            errorLocalizationKey: "resource.form.field.error.max.length",
            bundle: .commons
          )
        )
        .contraMap { resourceFieldValue -> String in
          switch resourceFieldValue {
          case let .string(value):
            return value
          }
        }
      }
    }

    func setFieldValue(
      _ value: ResourceFieldValue,
      field: ResourceField
    ) -> AnyPublisher<Void, TheError> {
      resourceTypePublisher
        .map { resourceType -> AnyPublisher<Validated<ResourceFieldValue>, TheError> in
          if let property: ResourceProperty = resourceType.properties.first(where: { $0.field == field }) {
            return Just(propertyValidator(for: property).validate(value))
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
          formValuesSubject.value[field] = validatedValue
        })
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    func fieldValuePublisher(
      field: ResourceField
    ) -> AnyPublisher<Validated<ResourceFieldValue>, Never> {
      formValuesSubject
        .map { formFields -> AnyPublisher<Validated<ResourceFieldValue>, Never> in
          if let fieldValue: Validated<ResourceFieldValue> = formFields[field] {
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

    func sendForm() -> AnyPublisher<Resource.ID, TheError> {
      Publishers.CombineLatest(
        resourceTypePublisher,
        formValuesSubject
          .setFailureType(to: TheError.self)
      )
      .first()
      .map {
        resourceType,
        validatedFieldValues -> AnyPublisher<
          (fieldValues: Dictionary<ResourceField, ResourceFieldValue>, encodedSecret: String), TheError
        > in
        var fieldValues: Dictionary<ResourceField, ResourceFieldValue> = .init()
        var secretFieldValues: Dictionary<ResourceField.RawValue, ResourceFieldValue> = .init()

        for (key, validatedValue) in validatedFieldValues {
          guard let property: ResourceProperty = resourceType.properties.first(where: { $0.field == key })
          else {
            assertionFailure("Trying to use form value that is not associated with any resource fields")
            continue
          }
          guard validatedValue.isValid
          else {
            return Fail(error: .validationError("resource.form.error.invalid", bundle: .commons))
              .eraseToAnyPublisher()
          }
          if property.encrypted {
            secretFieldValues[key.rawValue] = validatedValue.value
          }
          else {
            fieldValues[key] = validatedValue.value
          }
        }

        let encodedSecret: String? =
          (try? JSONEncoder().encode(secretFieldValues))
          .flatMap { String(data: $0, encoding: .utf8) }

        guard let encodedSecret: String = encodedSecret
        else {
          return Fail(error: .invalidResourceData())
            .eraseToAnyPublisher()
        }

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
            guard let name: String = fieldValues[.name]?.stringValue
            else {
              return Fail(
                error: .invalidOrMissingResourceType()
              )
              .eraseToAnyPublisher()
            }

            return
              accountSession
              .statePublisher()
              .first()
              .map { sessionState -> AnyPublisher<ArmoredPGPMessage, TheError> in
                switch sessionState {
                case let .authorized(account), let .authorizedMFARequired(account, _):
                  return
                    userPGPMessages
                    .encryptMessageForUser(.init(rawValue: account.userID.rawValue), encodedSecret)
                    .eraseToAnyPublisher()

                case .authorizationRequired, .none:
                  accountSession.requestAuthorizationPrompt(
                    .init(key: "authorization.prompt.refresh.session.reason", bundle: .main)
                  )
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
                      username: fieldValues[.username]?.stringValue,
                      url: fieldValues[.uri]?.stringValue,
                      description: fieldValues[.description]?.stringValue,
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
      setFieldValue: setFieldValue(_:field:),
      fieldValuePublisher: fieldValuePublisher(field:),
      sendForm: sendForm,
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension ResourceEditForm {

  public static var placeholder: ResourceEditForm {
    Self(
      resourceTypePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setFieldValue: Commons.placeholder("You have to provide mocks for used methods"),
      fieldValuePublisher: Commons.placeholder("You have to provide mocks for used methods"),
      sendForm: Commons.placeholder("You have to provide mocks for used methods"),
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
