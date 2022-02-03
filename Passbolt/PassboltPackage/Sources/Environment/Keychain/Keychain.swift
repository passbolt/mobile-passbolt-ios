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
import Foundation
import LocalAuthentication

public struct Keychain: EnvironmentElement {

  public var load: (KeychainQuery) -> Result<Array<Data>, Error>
  public var loadMeta: (KeychainQuery) -> Result<Array<KeychainItemMetadata>, Error>
  public var save: (Data, KeychainQuery) -> Result<Void, Error>
  public var delete: (KeychainQuery) -> Result<Void, Error>
}

extension Keychain {

  public static func live() -> Self {
    let biometricsContext: () -> LAContext = {
      let context: LAContext = .init()
      return context
    }

    func load(
      matching query: KeychainQuery
    ) -> Result<Array<Data>, Error> {
      let context: LAContext? =
        query.requiresBiometrics
        ? biometricsContext()
        : nil
      defer { context?.invalidate() }

      return loadKeychainData(
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: context
      )
    }

    func loadMeta(
      matching query: KeychainQuery
    ) -> Result<Array<KeychainItemMetadata>, Error> {
      let context: LAContext? =
        query.requiresBiometrics
        ? biometricsContext()
        : nil
      defer { context?.invalidate() }

      return loadKeychainMeta(
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: context
      )
      .map { results in
        results.compactMap { result in
          guard let rawKey: String = result[kSecAttrService] as? String
          else { return nil }
          let rawTag: String? = result[kSecAttrAccount] as? String
          return KeychainItemMetadata(
            key: .init(rawValue: rawKey),
            tag: rawTag.map(KeychainItemMetadata.Tag.init(rawValue:))
          )
        }
      }
    }

    func save(
      _ data: Data,
      for query: KeychainQuery
    ) -> Result<Void, Error> {
      let context: LAContext? =
        query.requiresBiometrics
        ? biometricsContext()
        : nil
      defer { context?.invalidate() }

      return saveKeychain(
        data: data,
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: context
      )
    }

    func delete(
      matching query: KeychainQuery
    ) -> Result<Void, Error> {
      deleteKeychainData(
        for: query.key.rawValue,
        tag: query.tag?.rawValue
      )
    }

    return Self(
      load: load(matching:),
      loadMeta: loadMeta(matching:),
      save: save(_:for:),
      delete: delete(matching:)
    )
  }
}

extension Keychain {

  public func loadAll<Value>(
    _: Value.Type = Value.self,
    matching query: KeychainQuery
  ) -> Result<Array<Value>, Error>
  where Value: Codable {
    load(query)
      .flatMap { items in
        do {
          return try .success(
            items.map { item in
              try jsonDecoder.decode(
                JSONWrapper<Value>.self,
                from: item
              ).v
            }
          )
        }
        catch {  // if any of values are invalid we treat it as error
          return .failure(
            KeychainAccessIssue.error(
              underlyingError:
                DataInvalid
                .error("Invalid data retrived from keychain")
                .recording(error, for: "underlyingError")
            )
          )
        }
      }
  }

  public func loadFirst<Value>(
    _: Value.Type = Value.self,
    matching query: KeychainQuery
  ) -> Result<Value?, Error>
  where Value: Codable {
    load(query)
      .flatMap { items in
        guard let firstItem = items.first
        else { return .success(nil) }
        do {
          return try .success(
            jsonDecoder.decode(
              JSONWrapper<Value>.self,
              from: firstItem
            ).v
          )
        }
        catch {  // if any of values are invalid we treat it as error
          return .failure(
            KeychainAccessIssue.error(
              underlyingError:
                DataInvalid
                .error("Invalid data retrived from keychain")
                .recording(error, for: "underlyingError")
            )
          )
        }
      }
  }

  public func loadMeta(
    matching query: KeychainQuery
  ) -> Result<Array<KeychainItemMetadata>, Error> {
    loadMeta(query)
  }

  public func save<Value>(
    _ value: Value,
    for query: KeychainQuery
  ) -> Result<Void, Error>
  where Value: Codable {
    do {
      return try save(
        jsonEncoder.encode(JSONWrapper(value)),
        query
      )
    }
    catch {
      return .failure(
        KeychainAccessIssue.error(
          underlyingError:
            DataInvalid
            .error("Tried to save invalid data to keychain")
            .recording(error, for: "underlyingError")
        )
      )
    }
  }

  public func delete(
    matching query: KeychainQuery
  ) -> Result<Void, Error> {
    delete(query)
  }
}

private let keychainShareGroupIdentifier: String = "UHX38H22ZT.com.passbolt.mobile"

private struct JSONWrapper<Value: Codable>: Codable {

  // data stored in keychain has a size limit,
  // stored data length can be reduced by using short identifier i.e. 'v'
  fileprivate var v: Value

  fileprivate init(_ value: Value) {
    self.v = value
  }
}

private let jsonEncoder = JSONEncoder()
private let jsonDecoder = JSONDecoder()

@inline(__always)
private func loadKeychainData(
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Array<Data>, Error> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else {
    return .failure(
      KeychainAccessIssue.error(
        underlyingError:
          KeychainAuthorizationFailure
          .error("Failed to access biometric authorization for loading keychain data")
          .recording(key, for: "key")
          .recording(tag as Any, for: "tag")
          .recording(errorPtr, for: "underlyingError")
      )
    )
  }
  return loadKeychainKeyQuery(using: key, tag: tag, in: context)
    .flatMap { query in
      var queryResult: AnyObject?
      let status: OSStatus = SecItemCopyMatching(
        query,
        &queryResult
      )
      switch status {
      case errSecSuccess:
        break  // continue

      case errSecItemNotFound:
        return .success([])

      case errSecAuthFailed:
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              KeychainAuthorizationFailure
              .error("Authorization failed for loading keychain data")
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
          )
        )

      case errSecUserCanceled:
        return .failure(
          Cancelled
            .error("Keychain access cancelled")
            .recording(key, for: "key")
            .recording(tag as Any, for: "tag")
        )

      case _:
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              KeychainFailure
              .error(
                "Failed to load keychain data",
                osStatus: status
              )
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
          )
        )
      }

      if let items: Array<Data> = queryResult as? Array<Data> {
        return .success(items)
      }
      else {
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              DataInvalid
              .error("Keychain data invalid")
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
              .recording(queryResult, for: "queryResult")
          )
        )
      }
    }
}

@inline(__always)
private func loadKeychainMeta(
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Array<Dictionary<CFString, Any>>, Error> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else {
    return .failure(
      KeychainAccessIssue.error(
        underlyingError:
          KeychainAuthorizationFailure
          .error("Failed to access biometric authorization for loading keychain data")
          .recording(key, for: "key")
          .recording(tag as Any, for: "tag")
          .recording(errorPtr, for: "underlyingError")
      )
    )
  }
  return loadKeychainMetaQuery(using: key, tag: tag, in: context)
    .flatMap { query in
      var queryResult: AnyObject?
      let status: OSStatus = SecItemCopyMatching(
        query,
        &queryResult
      )
      switch status {
      case errSecSuccess:
        break  // continue

      case errSecItemNotFound:
        return .success([])

      case errSecAuthFailed:
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              KeychainAuthorizationFailure
              .error("Authorization failed for loading keychain data")
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
          )
        )

      case errSecUserCanceled:
        return .failure(
          Cancelled
            .error("Keychain access cancelled")
            .recording(key, for: "key")
            .recording(tag as Any, for: "tag")
        )

      case _:
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              KeychainFailure
              .error(
                "Failed to load keychain data",
                osStatus: status
              )
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
          )
        )
      }

      if let items: Array<Dictionary<CFString, Any>> = queryResult as? Array<Dictionary<CFString, Any>> {
        return .success(items)
      }
      else {
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              DataInvalid
              .error("Keychain data invalid")
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
              .recording(queryResult as Any, for: "queryResult")
          )
        )
      }
    }
}

@inline(__always)
private func saveKeychain(
  data: Data,
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Void, Error> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else {
    return .failure(
      KeychainAccessIssue.error(
        underlyingError:
          KeychainAuthorizationFailure
          .error("Failed to access biometric authorization for saving keychain data")
          .recording(key, for: "key")
          .recording(tag as Any, for: "tag")
          .recording(errorPtr as Any, for: "underlyingError")
      )
    )
  }
  switch loadKeychainData(for: key, tag: tag, in: context) {
  case let .success(values) where !values.isEmpty:
    return updateKeychainKeyQuery(using: key, tag: tag, in: context)
      .flatMap { query in
        updateKeychainKeyAttributes(for: data)
          .flatMap { attributes in
            let status: OSStatus = SecItemUpdate(
              query,
              attributes
            )
            guard status == errSecSuccess
            else {
              return .failure(
                KeychainAccessIssue.error(
                  underlyingError:
                    KeychainFailure
                    .error(
                      "Failed to update keychain data",
                      osStatus: status
                    )
                    .recording(key, for: "key")
                    .recording(tag as Any, for: "tag")
                )
              )
            }
            return .success
          }
      }

  case .failure, .success:  // success without values aka errSecItemNotFound
    return saveKeychainKeyQuery(for: data, using: key, tag: tag, in: context)
      .flatMap { query in
        let status: OSStatus = SecItemAdd(
          query,
          nil
        )
        guard status == errSecSuccess
        else {
          return .failure(
            KeychainAccessIssue.error(
              underlyingError:
                KeychainFailure
                .error(
                  "Failed to save data to keychain",
                  osStatus: status
                )
                .recording(key, for: "key")
                .recording(tag as Any, for: "tag")
            )
          )
        }
        return .success
      }
  }
}

@inline(__always)
private func deleteKeychainData(
  for key: String,
  tag: String?
) -> Result<Void, Error> {
  deleteKeychainKeyQuery(using: key, tag: tag)
    .flatMap { query in
      let status: OSStatus = SecItemDelete(query)
      guard status == errSecSuccess || status == errSecItemNotFound
      else {
        return .failure(
          KeychainAccessIssue.error(
            underlyingError:
              KeychainFailure
              .error(
                "Failed to delete keychain data",
                osStatus: status
              )
              .recording(key, for: "key")
              .recording(tag as Any, for: "tag")
          )
        )
      }
      return .success
    }
}

@inline(__always)
private func loadKeychainKeyQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, Error> {
  assert(!key.isEmpty, "Cannot use empty identifier for keychain")
  var query: Dictionary<CFString, Any> = [
    kSecClass: kSecClassGenericPassword,
    kSecMatchLimit: kSecMatchLimitAll,
    kSecReturnAttributes: kCFBooleanFalse as Any,
    kSecReturnData: kCFBooleanTrue as Any,
    kSecAttrService: key,
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  }
  else {
    /* */
  }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrAccount] = tag
  }
  else {
    /* */
  }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else {
      return .failure(
        KeychainAccessIssue.error(
          underlyingError:
            KeychainQueryInvalid
            .error("'load' keychain query preparation failed")
            .recording(error?.takeRetainedValue() as Any, for: "underlyingError")
        )
      )
    }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func loadKeychainMetaQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, Error> {
  assert(!key.isEmpty, "Cannot use empty identifier for keychain")
  var query: Dictionary<CFString, Any> = [
    kSecClass: kSecClassGenericPassword,
    kSecMatchLimit: kSecMatchLimitAll,
    kSecReturnAttributes: kCFBooleanTrue as Any,
    kSecReturnData: kCFBooleanFalse as Any,
    kSecAttrService: key,
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  }
  else {
    /* */
  }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrAccount] = tag
  }
  else {
    /* */
  }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else {
      return .failure(
        KeychainAccessIssue.error(
          underlyingError:
            KeychainQueryInvalid
            .error("'load meta' keychain query preparation failed")
            .recording(error?.takeRetainedValue() as Any, for: "underlyingError")
        )
      )
    }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func saveKeychainKeyQuery(
  for data: Data,
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, Error> {
  assert(!key.isEmpty, "Cannot use empty identifier for keychain")
  assert(!data.isEmpty, "Cannot save empty data")

  var query: Dictionary<CFString, Any> = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrIsInvisible: kCFBooleanTrue as Any,
    kSecAttrService: key,
    kSecValueData: data,
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  }
  else {
    /* */
  }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrAccount] = tag
  }
  else {
    /* */
  }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else {
      return .failure(
        KeychainAccessIssue.error(
          underlyingError:
            KeychainQueryInvalid
            .error("'save' keychain query preparation failed")
            .recording(error?.takeRetainedValue() as Any, for: "underlyingError")
        )
      )
    }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func updateKeychainKeyQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, Error> {
  assert(!key.isEmpty, "Cannot use empty identifier for keychain")
  var query: Dictionary<CFString, Any> = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: key,
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  }
  else {
    /* */
  }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrAccount] = tag
  }
  else {
    /* */
  }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else {
      return .failure(
        KeychainAccessIssue.error(
          underlyingError:
            KeychainQueryInvalid
            .error("'update' keychain query preparation failed")
            .recording(error?.takeRetainedValue() as Any, for: "underlyingError")
        )
      )
    }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func updateKeychainKeyAttributes(
  for data: Data
) -> Result<CFDictionary, Error> {
  assert(!data.isEmpty, "Cannot save empty data")
  return .success([kSecValueData: data] as CFDictionary)
}

@inline(__always)
private func deleteKeychainKeyQuery(
  using key: String,
  tag: String?
) -> Result<CFDictionary, Error> {
  assert(!key.isEmpty, "Cannot use empty identifier for keychain")
  var query: Dictionary<CFString, Any> = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: key,
  ]
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrAccount] = tag
  }
  else {
    /* */
  }
  return .success(query as CFDictionary)
}

extension AppEnvironment {

  public var keychain: Keychain {
    get { element(Keychain.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension Keychain {

  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      load: unimplemented("You have to provide mocks for used methods"),
      loadMeta: unimplemented("You have to provide mocks for used methods"),
      save: unimplemented("You have to provide mocks for used methods"),
      delete: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
