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
  public var editResource: @StorageAccessActor (Resource.ID) -> AnyPublisher<Void, Error>
  // set enclosing folder (parentFolderID)
  public var setEnclosingFolder: (ResourceFolder.ID?) -> Void
  // initial version supports only one type of resource type, so there is no method to change it
  public var resourceTypePublisher: () -> AnyPublisher<ResourceTypeDSV, Error>
  // since currently the only field value is String we are not allowing other value types
  public var setFieldValue: (ResourceFieldValue, ResourceFieldName) -> AnyPublisher<Void, Error>
  // prepare publisher for given field, publisher will complete when field will be no longer available
  public var fieldValuePublisher: (ResourceFieldName) -> AnyPublisher<Validated<ResourceFieldValue>, Never>
  // send the form and create resource on server
  public var sendForm: @AccountSessionActor () -> AnyPublisher<Resource.ID, Error>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension ResourceEditForm: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountSession: AccountSession = try await features.instance()
    let database: AccountDatabase = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let userPGPMessages: UserPGPMessages = try await features.instance()
    let resources: Resources = try await features.instance()

    let resourceIDSubject: CurrentValueSubject<Resource.ID?, Never> = .init(nil)
    let resourceParentFolderIDSubject: CurrentValueSubject<ResourceFolder.ID?, Never> = .init(nil)
    let resourceTypeSubject: CurrentValueSubject<ResourceTypeDSV?, Error> = .init(nil)
    let resourceTypePublisher: AnyPublisher<ResourceTypeDSV, Error> =
      resourceTypeSubject.filterMapOptional().eraseToAnyPublisher()
    let formValuesSubject: CurrentValueSubject<Dictionary<ResourceFieldName, Validated<ResourceFieldValue>>, Never> =
      .init(.init())

    // load initial resource type
    database
      .fetchResourcesTypesOperation()
      .eraseErrorType()
      .map { resourceTypes -> AnyPublisher<ResourceTypeDSV, Error> in
        // in initial version we are supporting only one type of resource for being created
        if let resourceType: ResourceTypeDSV = resourceTypes.first(where: \.isDefault) {
          return Just(resourceType)
            .eraseErrorType()
            .eraseToAnyPublisher()
        }
        else {
          return Fail(error: TheErrorLegacy.invalidOrMissingResourceType())
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
          let removedFields: Array<ResourceFieldNameDSV> = formValuesSubject.value.keys.filter { key in
            !resourceType.fields.contains(where: { $0.name == key })
          }
          for removedField in removedFields {
            formValuesSubject.value.removeValue(forKey: removedField)
          }

          // add new fields (if any) and validate again existing ones
          for field in resourceType.fields {
            let fieldValue: ResourceFieldValue =
              formValuesSubject.value[field.name]?.value
              ?? .init(defaultFor: field.valueType)
            formValuesSubject.value[field.name] =
              propertyValidator(for: field)
              .validate(fieldValue)
          }
        }
      )
      .store(in: cancellables)

    @StorageAccessActor func editResource(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<Void, Error> {
      assert(
        resourceIDSubject.value == nil,
        "Edited resource change is not supported"
      )
      return
        database
        .fetchEditViewResourceOperation(resourceID)
        .eraseErrorType()
        .asyncMap { resource in
          await resources
            .loadResourceSecret(resource.id)
            .map { secret in (resource, secret) }
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(
          receiveOutput: { resource, secret in
            resourceTypeSubject.send(resource.type)
            resourceIDSubject.send(resource.id)
            resourceParentFolderIDSubject.send(resource.parentFolderID)
            for field in resource.type.fields {
              switch field.name {
              case .name:
                formValuesSubject.value[.name] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      fromString: resource.name,
                      forType: field.valueType
                    )
                  )

              case .uri:
                formValuesSubject.value[.uri] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      fromString: resource.url ?? "",
                      forType: field.valueType
                    )
                  )

              case .username:
                formValuesSubject.value[.username] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      fromString: resource.username ?? "",
                      forType: field.valueType
                    )
                  )

              case .password:
                formValuesSubject.value[.password] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      fromString: secret.password ?? "",
                      forType: field.valueType
                    )
                  )

              case .description:
                let stringValue: String
                if field.encrypted {
                  stringValue = secret.description ?? ""
                }
                else {
                  stringValue = resource.description ?? ""
                }
                formValuesSubject.value[.description] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      fromString: stringValue,
                      forType: field.valueType
                    )
                  )

              case let .undefined(name: name):
                formValuesSubject.value[.undefined(name: name)] =
                  propertyValidator(
                    for: field
                  )
                  .validate(
                    .init(
                      defaultFor: field.valueType
                    )
                  )
              }
            }
          }
        )
        .mapToVoid()
        .eraseToAnyPublisher()
    }

    nonisolated func setEnclosingFolder(_ folderID: ResourceFolder.ID?) {
      resourceParentFolderIDSubject.send(folderID)
    }

    nonisolated func propertyValidator(
      for property: ResourceFieldDSV
    ) -> Validator<ResourceFieldValue> {
      switch property.valueType {
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

    nonisolated func setFieldValue(
      _ value: ResourceFieldValue,
      fieldName: ResourceFieldName
    ) -> AnyPublisher<Void, Error> {
      resourceTypePublisher
        .map { resourceType -> AnyPublisher<Validated<ResourceFieldValue>, Error> in
          if let field: ResourceFieldDSV = resourceType.fields.first(where: { $0.name == fieldName }) {
            return Just(propertyValidator(for: field).validate(value))
              .eraseErrorType()
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: TheErrorLegacy.invalidOrMissingResourceType())
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

    nonisolated func fieldValuePublisher(
      field: ResourceFieldName
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

    @AccountSessionActor func sendForm() -> AnyPublisher<Resource.ID, Error> {
      Publishers.CombineLatest3(
        resourceIDSubject
          .eraseErrorType(),
        resourceTypePublisher,
        formValuesSubject
          .eraseErrorType()
      )
      .first()
      .map {
        resourceID,
        resourceType,
        validatedFieldValues -> AnyPublisher<
          (
            resourceID: Resource.ID?,
            resourceTypeID: ResourceType.ID,
            fieldValues: Dictionary<ResourceFieldName, ResourceFieldValue>,
            encodedSecret: String
          ),
          Error
        > in
        var fieldValues: Dictionary<ResourceFieldName, ResourceFieldValue> = .init()
        var secretFieldValues: Dictionary<ResourceFieldName.RawValue, ResourceFieldValue> = .init()

        for (key, validatedValue) in validatedFieldValues {
          guard let field: ResourceFieldDSV = resourceType.fields.first(where: { $0.name == key })
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
            )
            .eraseToAnyPublisher()
          }
          if field.encrypted {
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
          return Fail(error: TheErrorLegacy.invalidResourceData(underlyingError: error))
            .eraseToAnyPublisher()
        }

        guard let encodedSecret: String = encodedSecret
        else {
          return Fail(error: TheErrorLegacy.invalidResourceData())
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
        .eraseErrorType()
        .eraseToAnyPublisher()
      }
      .switchToLatest()
      .map { (resourceID, resourceTypeID, fieldValues, encodedSecret) -> AnyPublisher<Resource.ID, Error> in
        guard let name: String = fieldValues[.name]?.stringValue
        else {
          return Fail(error: TheErrorLegacy.invalidOrMissingResourceType())
            .eraseToAnyPublisher()
        }
        let parentFolderID: ResourceFolder.ID? = resourceParentFolderIDSubject.value

        if let resourceID: Resource.ID = resourceID {
          return
            accountSession
            .statePublisher()
            .first()
            .map { sessionState -> AnyPublisher<Array<(User.ID, ArmoredPGPMessage)>, Error> in
              switch sessionState {
              case .authorized, .authorizedMFARequired:
                return
                  userPGPMessages
                  .encryptMessageForResourceUsers(resourceID, encodedSecret)
                  .eraseToAnyPublisher()

              case let .authorizationRequired(account):
                return Fail(
                  error:
                    SessionAuthorizationRequired
                    .error(
                      "Session authorization required for editing resource",
                      account: account
                    )
                )
                .eraseToAnyPublisher()

              case .none:
                return Fail(
                  error:
                    SessionMissing
                    .error("No session provided for editing resource")
                )
                .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .map { encryptedSecrets -> AnyPublisher<Resource.ID, Error> in
              networkClient
                .updateResourceRequest
                .make(
                  using: .init(
                    resourceID: resourceID.rawValue,
                    resourceTypeID: resourceTypeID.rawValue,
                    parentFolderID: parentFolderID?.rawValue,
                    name: name,
                    username: fieldValues[.username]?.stringValue,
                    url: fieldValues[.uri]?.stringValue,
                    description: fieldValues[.description]?.stringValue,
                    secrets: encryptedSecrets.map { (userID: $0.rawValue, data: $1.rawValue) }
                  )
                )
                .eraseErrorType()
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
                Array<(userID: User.ID, encryptedMessage: ArmoredPGPMessage)>, Error
              > in
              switch sessionState {
              case let .authorized(account), let .authorizedMFARequired(account, _):
                return
                  userPGPMessages
                  .encryptMessageForUser(.init(rawValue: account.userID.rawValue), encodedSecret)
                  .map { encryptedMessage in [(.init(rawValue: account.userID.rawValue), encryptedMessage)] }
                  .eraseToAnyPublisher()

              case let .authorizationRequired(account):
                return Fail(
                  error:
                    SessionAuthorizationRequired
                    .error(
                      "Session authorization required for creating resource",
                      account: account
                    )
                )
                .eraseToAnyPublisher()

              case .none:
                return Fail(
                  error:
                    SessionMissing
                    .error("No session provided for creating resource")
                )
                .eraseToAnyPublisher()

              }
            }
            .switchToLatest()
            .map { encryptedSecrets -> AnyPublisher<Resource.ID, Error> in
              return
                networkClient
                .createResourceRequest
                .make(
                  using: .init(
                    resourceTypeID: resourceTypeID.rawValue,
                    parentFolderID: parentFolderID?.rawValue,
                    name: name,
                    username: fieldValues[.username]?.stringValue,
                    url: fieldValues[.uri]?.stringValue,
                    description: fieldValues[.description]?.stringValue,
                    secretData: encryptedSecrets.first?.encryptedMessage.rawValue ?? ""
                  )
                )
                .eraseErrorType()
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

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      editResource: editResource(_:),
      setEnclosingFolder: setEnclosingFolder(_:),
      resourceTypePublisher: { resourceTypePublisher },
      setFieldValue: setFieldValue(_:fieldName:),
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
      setEnclosingFolder: unimplemented("You have to provide mocks for used methods"),
      resourceTypePublisher: unimplemented("You have to provide mocks for used methods"),
      setFieldValue: unimplemented("You have to provide mocks for used methods"),
      fieldValuePublisher: unimplemented("You have to provide mocks for used methods"),
      sendForm: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
