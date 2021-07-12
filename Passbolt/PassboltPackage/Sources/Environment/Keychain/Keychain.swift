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

import Commons
import Foundation
import LocalAuthentication

public struct Keychain: EnvironmentElement {

  public var load: (KeychainQuery) -> Result<Array<Data>, TheError>
  public var loadMeta: (KeychainQuery) -> Result<Array<KeychainItemMetadata>, TheError>
  public var save: (Data, KeychainQuery) -> Result<Void, TheError>
  public var delete: (KeychainQuery) -> Result<Void, TheError>
}

// we would like to ask every time but some methods request it multiple times in a row, so using small timout
private let keychainBiometricsTimeout: TimeInterval = 0.1  // 0.1 sec

extension Keychain {

  public static func live() -> Self {
    let biometricsContext: () -> LAContext = {
      let context: LAContext = .init()
      context.touchIDAuthenticationAllowableReuseDuration = keychainBiometricsTimeout
      return context
    }

    func load(
      matching query: KeychainQuery
    ) -> Result<Array<Data>, TheError> {
      loadKeychainData(
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: query.requiresBiometrics
          ? biometricsContext()
          : nil
      )
    }

    func loadMeta(
      matching query: KeychainQuery
    ) -> Result<Array<KeychainItemMetadata>, TheError> {
      loadKeychainMeta(
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: query.requiresBiometrics
          ? biometricsContext()
          : nil
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
    ) -> Result<Void, TheError> {
      saveKeychain(
        data: data,
        for: query.key.rawValue,
        tag: query.tag?.rawValue,
        in: query.requiresBiometrics
          ? biometricsContext()
          : nil
      )
    }

    func delete(
      matching query: KeychainQuery
    ) -> Result<Void, TheError> {
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
  ) -> Result<Array<Value>, TheError>
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
            .keychainError(
              errSecInvalidData,
              underlyingError: error
            )
          )
        }
      }
  }

  public func loadFirst<Value>(
    _: Value.Type = Value.self,
    matching query: KeychainQuery
  ) -> Result<Value?, TheError>
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
            .keychainError(
              errSecInvalidData,
              underlyingError: error
            )
          )
        }
      }
  }

  public func loadMeta(
    matching query: KeychainQuery
  ) -> Result<Array<KeychainItemMetadata>, TheError> {
    loadMeta(query)
  }

  public func save<Value>(
    _ value: Value,
    for query: KeychainQuery
  ) -> Result<Void, TheError>
  where Value: Codable {
    do {
      return try save(
        jsonEncoder.encode(JSONWrapper(value)),
        query
      )
    }
    catch {
      return .failure(
        .keychainError(
          errSecInvalidData,
          underlyingError: error
        )
      )
    }
  }

  public func delete(
    matching query: KeychainQuery
  ) -> Result<Void, TheError> {
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
) -> Result<Array<Data>, TheError> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else { return .failure(.keychainError(errSecNotAvailable, underlyingError: errorPtr)) }
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
        return .failure(.keychainAuthFailed())

      case _:
        return .failure(.keychainError(status))
      }

      if let items: Array<Data> = queryResult as? Array<Data> {
        return .success(items)
      }
      else {
        return .failure(.keychainError(errSecDataNotAvailable))
      }
    }
}

@inline(__always)
private func loadKeychainMeta(
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Array<Dictionary<CFString, Any>>, TheError> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else { return .failure(.keychainError(errSecNotAvailable, underlyingError: errorPtr)) }
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
        return .failure(.keychainAuthFailed())

      case _:
        return .failure(.keychainError(status))
      }

      if let items: Array<Dictionary<CFString, Any>> = queryResult as? Array<Dictionary<CFString, Any>> {
        return .success(items)
      }
      else {
        return .failure(.keychainError(errSecDataNotAvailable))
      }
    }
}

@inline(__always)
private func saveKeychain(
  data: Data,
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Void, TheError> {
  var errorPtr: NSError?
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorPtr) ?? true
  else { return .failure(.keychainError(errSecNotAvailable, underlyingError: errorPtr)) }
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
            else { return .failure(.keychainError(status)) }
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
        else { return .failure(.keychainError(status)) }
        return .success
      }
  }
}

@inline(__always)
private func deleteKeychainData(
  for key: String,
  tag: String?
) -> Result<Void, TheError> {
  deleteKeychainKeyQuery(using: key, tag: tag)
    .flatMap { query in
      let status: OSStatus = SecItemDelete(query)
      guard status == errSecSuccess || status == errSecItemNotFound
      else { return .failure(.keychainError(status)) }
      return .success
    }
}

@inline(__always)
private func loadKeychainKeyQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, TheError> {
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
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else { return .failure(.keychainError(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func loadKeychainMetaQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, TheError> {
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
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else { return .failure(.keychainError(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func saveKeychainKeyQuery(
  for data: Data,
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, TheError> {
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
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else { return .failure(.keychainError(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func updateKeychainKeyQuery(
  using key: String,
  tag: String?,
  in context: LAContext?
) -> Result<CFDictionary, TheError> {
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
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
      ),
      error == nil
    else { return .failure(.keychainError(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  }
  else {
    query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  }
  return .success(query as CFDictionary)
}

@inline(__always)
private func updateKeychainKeyAttributes(
  for data: Data
) -> Result<CFDictionary, TheError> {
  assert(!data.isEmpty, "Cannot save empty data")
  return .success([kSecValueData: data] as CFDictionary)
}

@inline(__always)
private func deleteKeychainKeyQuery(
  using key: String,
  tag: String?
) -> Result<CFDictionary, TheError> {
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

extension Environment {

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
      load: Commons.placeholder("You have to provide mocks for used methods"),
      loadMeta: Commons.placeholder("You have to provide mocks for used methods"),
      save: Commons.placeholder("You have to provide mocks for used methods"),
      delete: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
