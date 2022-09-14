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

import CommonModels
import Crypto
import DatabaseOperations
import Features
import NetworkOperations
import Resources
import Users

import class Foundation.JSONEncoder

// MARK: - Implementation

extension ResourceEditForm {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let usersPGPMessages: UsersPGPMessages = try await features.instance()
    let resources: Resources = try await features.instance()
    let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try await features.instance()
    let resourceEditDetailsFetchDatabaseOperation: ResourceEditDetailsFetchDatabaseOperation =
      try await features.instance()
    let resourceEditNetworkOperation: ResourceEditNetworkOperation = try await features.instance()
    let resourceCreateNetworkOperation: ResourceCreateNetworkOperation = try await features.instance()
    let resourceShareNetworkOperation: ResourceShareNetworkOperation = try await features.instance()
    let session: Session = try await features.instance()
    let resourceFolderPermissionsFetchDatabaseOperation: ResourceFolderPermissionsFetchDatabaseOperation = try await features.instance()

    let resourceIDSubject: CurrentValueSubject<Resource.ID?, Never> = .init(nil)
    let resourceParentFolderIDSubject: CurrentValueSubject<ResourceFolder.ID?, Never> = .init(nil)
    let resourceTypeSubject: CurrentValueSubject<ResourceTypeDSV?, Error> = .init(nil)
    let resourceTypePublisher: AnyPublisher<ResourceTypeDSV, Error> =
      resourceTypeSubject.filterMapOptional().eraseToAnyPublisher()
    let formValuesSubject: CurrentValueSubject<Dictionary<ResourceFieldName, Validated<ResourceFieldValue>>, Never> =
      .init(.init())

    // load initial resource type
    Just(Void())
      .eraseErrorType()
      .asyncMap {
        try await resourceTypesFetchDatabaseOperation()
      }
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

    @Sendable nonisolated func editResource(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<Void, Error> {
      assert(
        resourceIDSubject.value == nil,
        "Edited resource change is not supported"
      )
      return Just(Void())
        .eraseErrorType()
        .asyncMap { () async throws -> (ResourceEditDetailsDSV, ResourceSecret) in
          let resource = try await resourceEditDetailsFetchDatabaseOperation(resourceID)
          let secret =
            try await resources
            .loadResourceSecret(resource.id)
            .asAsyncValue()

          return (resource, secret)
        }
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

    @Sendable nonisolated func setEnclosingFolder(_ folderID: ResourceFolder.ID?) {
      resourceParentFolderIDSubject.send(folderID)
    }

    @Sendable nonisolated func propertyValidator(
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

    @Sendable nonisolated func setFieldValue(
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

    @Sendable nonisolated func fieldValuePublisher(
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

    @Sendable nonisolated func sendForm() -> AnyPublisher<Resource.ID, Error> {
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
      .asyncMap { (resourceID, resourceTypeID, fieldValues, encodedSecret) async throws -> Resource.ID in
        guard let name: String = fieldValues[.name]?.stringValue
        else {
          throw
            TheErrorLegacy
            .invalidOrMissingResourceType()
        }
        let parentFolderID: ResourceFolder.ID? = resourceParentFolderIDSubject.value

        if let resourceID: Resource.ID = resourceID {
          let encryptedSecrets: OrderedSet<EncryptedMessage> =
            try await usersPGPMessages
            .encryptMessageForResourceUsers(resourceID, encodedSecret)

          let updatedResourceID: Resource.ID = try await resourceEditNetworkOperation(
            .init(
              resourceID: resourceID,
              resourceTypeID: resourceTypeID,
              parentFolderID: parentFolderID,
              name: name,
              username: fieldValues[.username]?.stringValue,
              url: (fieldValues[.uri]?.stringValue).flatMap(URLString.init(rawValue:)),
              description: fieldValues[.description]?.stringValue,
              secrets: encryptedSecrets.map { (userID: $0.recipient, data: $0.message) }
            )
          )
          .resourceID

          return updatedResourceID
        }
        else {
          let account: Account = try await session.currentAccount()

          guard let ownEncryptedMessage: EncryptedMessage = try await usersPGPMessages.encryptMessageForUsers([account.userID], encodedSecret)
            .first
          else {
            throw
              UserSecretMissing
              .error()
          }

          let newResourceID: Resource.ID = try await resourceCreateNetworkOperation(
            .init(
              resourceTypeID: resourceTypeID,
              parentFolderID: parentFolderID,
              name: name,
              username: fieldValues[.username]?.stringValue,
              url: (fieldValues[.uri]?.stringValue).flatMap(URLString.init(rawValue:)),
              description: fieldValues[.description]?.stringValue,
              secrets: [ownEncryptedMessage]
            )
          )
          .resourceID

          if let folderID: ResourceFolder.ID = parentFolderID {
            let encryptedSecrets: OrderedSet<EncryptedMessage> =
            try await usersPGPMessages
              .encryptMessageForResourceFolderUsers(folderID, encodedSecret)
              .filter { encryptedMessage in
                encryptedMessage.recipient != account.userID
              }
							.asOrderedSet()

            let folderPermissions: Array<ResourceFolderPermissionDSV> = try await resourceFolderPermissionsFetchDatabaseOperation(folderID)
              .filter { permission in
                switch permission {
                case .user(account.userID, _):
                  return false

                case _:
                  return true
                }
              }

            try await resourceShareNetworkOperation(
              .init(
                resourceID: newResourceID,
                body: .init(
                  newPermissions: OrderedSet(
                    folderPermissions
                      .map { folderPermission -> NewPermissionDTO in
                        switch folderPermission {
                        case let .user(id, permissionType):
                          return .userToFolder(
                              userID: id,
                              folderID: folderID,
                              type: permissionType
                            )

                        case let .userGroup(id, permissionType):
                          return .userGroupToFolder(
                              userGroupID: id,
                              folderID: folderID,
                              type: permissionType
                            )
                        }
                      }
                  ),
                  updatedPermissions: .init(),
                  deletedPermissions: .init(),
                  newSecrets: encryptedSecrets
                )
              )
            )
          } // else continue without sharing

          return newResourceID
        }
      }
      .eraseToAnyPublisher()
    }

    return Self(
      editResource: editResource(_:),
      setEnclosingFolder: setEnclosingFolder(_:),
      resourceTypePublisher: { resourceTypePublisher },
      setFieldValue: setFieldValue(_:fieldName:),
      fieldValuePublisher: fieldValuePublisher(field:),
      sendForm: sendForm
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceEditForm() {
    self.use(
      .lazyLoaded(
        ResourceEditForm.self,
        load: ResourceEditForm.load(features:cancellables:)
      )
    )
  }
}
