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
import Features
import NetworkClient
import Users

import class Foundation.JSONEncoder

public struct ResourceEditForm {

  // sets currently edited resource, if it was not set default form creates new resource
  // note that editing resource will download and decrypt secrets to fill them in and allow editing
  public var editResource: (Resource.ID) -> AnyPublisher<Void, TheErrorLegacy>
  // initial version supports only one type of resource type, so there is no method to change it
  public var resourceTypePublisher: () -> AnyPublisher<ResourceType, TheErrorLegacy>
  // since currently the only field value is String we are not allowing other value types
  public var setFieldValue: (ResourceFieldValue, ResourceField) -> AnyPublisher<Void, TheErrorLegacy>
  // prepare publisher for given field, publisher will complete when field will be no longer available
  public var fieldValuePublisher: (ResourceField) -> AnyPublisher<Validated<ResourceFieldValue>, Never>
  // send the form and create resource on server
  public var sendForm: () -> AnyPublisher<Resource.ID, TheErrorLegacy>
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
    let resources: Resources = features.instance()

    let editedResourceIDSubject: CurrentValueSubject<Resource.ID?, Never> = .init(nil)
    let resourceTypeSubject: CurrentValueSubject<ResourceType?, TheErrorLegacy> = .init(nil)
    let resourceTypePublisher: AnyPublisher<ResourceType, TheErrorLegacy> =
      resourceTypeSubject.filterMapOptional().eraseToAnyPublisher()
    let formValuesSubject: CurrentValueSubject<Dictionary<ResourceField, Validated<ResourceFieldValue>>, Never> =
      .init(.init())

    // load initial resource type
    database
      .fetchResourcesTypesOperation()
      .map { resourceTypes -> AnyPublisher<ResourceType, TheErrorLegacy> in
        // in initial version we are supporting only one type of resource for being created
        if let resourceType: ResourceType = resourceTypes.first(where: \.isDefault) {
          return Just(resourceType)
            .setFailureType(to: TheErrorLegacy.self)
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
          resourceTypeSubject.send(resourceType)
        }
      )
      .store(in: cancellables)

    // handle current resource type updates
    resourceTypePublisher
      .removeDuplicates(by: { $0.id == $1.id })
      .sink(
        receiveCompletion: { _ in /* NOP */ },
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
        }
      )
      .store(in: cancellables)

    func editResource(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      assert(
        editedResourceIDSubject.value == nil,
        "Edited resource change is not supported"
      )
      return
        database
        .fetchEditViewResourceOperation(resourceID)
        .map { resource in
          resources
            .loadResourceSecret(resource.id)
            .map { secret in (resource, secret) }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(
          receiveOutput: { resource, secret in
            resourceTypeSubject.send(resource.type)
            editedResourceIDSubject.send(resource.id)
            for property in resource.type.properties {
              switch property.field {
              case .name:
                formValuesSubject.value[.name] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      fromString: resource.name,
                      forType: property.type
                    )
                  )

              case .uri:
                formValuesSubject.value[.uri] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      fromString: resource.url ?? "",
                      forType: property.type
                    )
                  )

              case .username:
                formValuesSubject.value[.username] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      fromString: resource.username ?? "",
                      forType: property.type
                    )
                  )

              case .password:
                formValuesSubject.value[.password] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      fromString: secret.password ?? "",
                      forType: property.type
                    )
                  )

              case .description:
                let stringValue: String
                if property.encrypted {
                  stringValue = secret.description ?? ""
                }
                else {
                  stringValue = resource.description ?? ""
                }
                formValuesSubject.value[.description] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      fromString: stringValue,
                      forType: property.type
                    )
                  )

              case let .undefined(name: name):
                formValuesSubject.value[.undefined(name: name)] =
                  propertyValidator(
                    for: property
                  )
                  .validate(
                    .init(
                      defaultFor: property.type
                    )
                  )
              }
            }
          }
        )
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    func propertyValidator(
      for property: ResourceProperty
    ) -> Validator<ResourceFieldValue> {
      switch property.type {
      case .string:
        return zip(
          {
            if property.required {
              return .nonEmpty(
                displayable: .localized(
                  key: "resource.form.field.error.empty"
                )
              )
            }
            else {
              return .alwaysValid
            }
          }(),
          // even if there is no requirement for max length we are limiting it with
          // some high value to prevent too big values
          .maxLength(
            UInt(property.maxLength ?? 10000),
            displayable: .localized(
              key: "resource.form.field.error.max.length"
            )
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
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      resourceTypePublisher
        .map { resourceType -> AnyPublisher<Validated<ResourceFieldValue>, TheErrorLegacy> in
          if let property: ResourceProperty = resourceType.properties.first(where: { $0.field == field }) {
            return Just(propertyValidator(for: property).validate(value))
              .setFailureType(to: TheErrorLegacy.self)
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
            return Empty()
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .removeDuplicates { lhs, rhs in
          lhs.value == rhs.value && lhs.isValid == rhs.isValid
        }
        .eraseToAnyPublisher()
    }

    func sendForm() -> AnyPublisher<Resource.ID, TheErrorLegacy> {
      Publishers.CombineLatest3(
        editedResourceIDSubject
          .setFailureType(to: TheErrorLegacy.self),
        resourceTypePublisher,
        formValuesSubject
          .setFailureType(to: TheErrorLegacy.self)
      )
      .first()
      .map {
        resourceID,
        resourceType,
        validatedFieldValues -> AnyPublisher<
          (
            resourceID: Resource.ID?,
            resourceTypeID: ResourceType.ID,
            fieldValues: Dictionary<ResourceField, ResourceFieldValue>,
            encodedSecret: String
          ),
          TheErrorLegacy
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
            return Fail(
              error:
                InvalidForm
                .error(
                  displayable: .localized(
                    key: "resource.form.error.invalid"
                  )
                )
                .asLegacy
            )
            .eraseToAnyPublisher()
          }
          if property.encrypted {
            secretFieldValues[key.rawValue] = validatedValue.value
          }
          else {
            fieldValues[key] = validatedValue.value
          }
        }

        let encodedSecret: String?
        do {
          if secretFieldValues.count == 1,
            let password: ResourceFieldValue = secretFieldValues["password"]
          {
            encodedSecret = password.stringValue
          }
          else {
            encodedSecret = try String(data: JSONEncoder().encode(secretFieldValues), encoding: .utf8)
          }
        }
        catch {
          return Fail(error: .invalidResourceData(underlyingError: error))
            .eraseToAnyPublisher()
        }

        guard let encodedSecret: String = encodedSecret
        else {
          return Fail(error: .invalidResourceData())
            .eraseToAnyPublisher()
        }

        return Just(
          (
            resourceID: resourceID,
            resourceTypeID: resourceType.id,
            fieldValues: fieldValues,
            encodedSecret: encodedSecret
          )
        )
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
      }
      .switchToLatest()
      .map { (resourceID, resourceTypeID, fieldValues, encodedSecret) -> AnyPublisher<Resource.ID, TheErrorLegacy> in
        guard let name: String = fieldValues[.name]?.stringValue
        else {
          return Fail(error: .invalidOrMissingResourceType())
            .eraseToAnyPublisher()
        }

        if let resourceID: Resource.ID = resourceID {
          return
            accountSession
            .statePublisher()
            .first()
            .map { sessionState -> AnyPublisher<Array<(User.ID, ArmoredPGPMessage)>, TheErrorLegacy> in
              switch sessionState {
              case .authorized, .authorizedMFARequired:
                return
                  userPGPMessages
                  .encryptMessageForResourceUsers(resourceID, encodedSecret)
                  .eraseToAnyPublisher()

              case .authorizationRequired, .none:
                accountSession.requestAuthorizationPrompt(
                  .localized("authorization.prompt.refresh.session.reason")
                )
                return Fail(error: .authorizationRequired())
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .map { encryptedSecrets -> AnyPublisher<Resource.ID, TheErrorLegacy> in
              networkClient
                .updateResourceRequest
                .make(
                  using: .init(
                    resourceID: resourceID.rawValue,
                    resourceTypeID: resourceTypeID.rawValue,
                    name: name,
                    username: fieldValues[.username]?.stringValue,
                    url: fieldValues[.uri]?.stringValue,
                    description: fieldValues[.description]?.stringValue,
                    secrets: encryptedSecrets.map { (userID: $0.rawValue, data: $1.rawValue) }
                  )
                )
                .mapErrorsToLegacy()
                .map { response -> Resource.ID in .init(rawValue: response.body.resourceID) }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        else {
          return
            accountSession
            .statePublisher()
            .first()
            .map {
              sessionState -> AnyPublisher<
                Array<(userID: User.ID, encryptedMessage: ArmoredPGPMessage)>, TheErrorLegacy
              > in
              switch sessionState {
              case let .authorized(account), let .authorizedMFARequired(account, _):
                return
                  userPGPMessages
                  .encryptMessageForUser(.init(rawValue: account.userID.rawValue), encodedSecret)
                  .map { encryptedMessage in [(.init(rawValue: account.userID.rawValue), encryptedMessage)] }
                  .eraseToAnyPublisher()

              case .authorizationRequired, .none:
                accountSession.requestAuthorizationPrompt(
                  .localized("authorization.prompt.refresh.session.reason")
                )
                return Fail(error: .authorizationRequired())
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .map { encryptedSecrets -> AnyPublisher<Resource.ID, TheErrorLegacy> in
              return
                networkClient
                .createResourceRequest
                .make(
                  using: .init(
                    resourceTypeID: resourceTypeID.rawValue,
                    name: name,
                    username: fieldValues[.username]?.stringValue,
                    url: fieldValues[.uri]?.stringValue,
                    description: fieldValues[.description]?.stringValue,
                    secretData: encryptedSecrets.first?.encryptedMessage.rawValue ?? ""
                  )
                )
                .mapErrorsToLegacy()
                .map { response -> Resource.ID in .init(rawValue: response.body.resourceID) }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func featureUnload() -> Bool {
      true
    }

    return Self(
      editResource: editResource(_:),
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
      editResource: unimplemented("You have to provide mocks for used methods"),
      resourceTypePublisher: unimplemented("You have to provide mocks for used methods"),
      setFieldValue: unimplemented("You have to provide mocks for used methods"),
      fieldValuePublisher: unimplemented("You have to provide mocks for used methods"),
      sendForm: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
