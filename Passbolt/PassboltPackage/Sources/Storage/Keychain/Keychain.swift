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

import Combine
import Commons
import Foundation
import LocalAuthentication

public struct Keychain {
  
  public var verifyBiometricsPermission: () -> AnyPublisher<Bool, TheError>
  public var load: (KeychainItemIdentifier) -> Result<Data, TheError>
  public var save: (Data, KeychainItemIdentifier) -> Result<Void, TheError>
  public var delete: (KeychainItemIdentifier) -> Result<Void, TheError>
}

extension Keychain {
  
  public static func keychain() -> Self {
    Self(
      verifyBiometricsPermission: {
        let context: LAContext = biometricsContext()
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
          return Just(true)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        } else {
          let completionSubject: PassthroughSubject<Bool, TheError> = .init()
          if !isInExtensionContext {
            DispatchQueue.main.async {
              #warning("TODO: Provide localized string for reason")
              context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "TODO: reason"
              ) { granted, error in
                if error != nil {
                  completionSubject.send(
                    completion: .failure(.keychain(errSecNotAvailable))
                  )
                } else {
                  completionSubject.send(granted)
                  completionSubject.send(completion: .finished)
                }
              }
            }
          } else { /* */ }
          return completionSubject
            .eraseToAnyPublisher()
        }
      },
      load: { identifier in
        loadKeychainData(
          for: identifier.key.rawValue,
          tag: identifier.tag?.rawValue,
          in: identifier.requiresBiometrics
            ? biometricsContext()
            : nil
        )
      },
      save: { data, identifier in
        saveKeychain(
          data: data,
          for: identifier.key.rawValue,
          tag: identifier.tag?.rawValue,
          in: identifier.requiresBiometrics
            ? biometricsContext()
            : nil
        )
      },
      delete: { identifier in
        deleteKeychainData(
          for: identifier.key.rawValue,
          tag: identifier.tag?.rawValue
        )
      }
    )
  }
}

extension Keychain {
  
  public func load<Value>(
    _: Value.Type = Value.self,
    for item: KeychainItem<Value>
  ) -> Result<Value, TheError>
  where Value: Codable {
    load(item.identifier)
      .flatMap { data in
        do {
          return try .success(
            jsonDecoder.decode(JSONWrapper<Value>.self, from: data).v
          )
        } catch {
          return .failure(.keychain(errSecInvalidData))
        }
      }
  }
  
  public func save<Value>(
    _ value: Value,
    for item: KeychainItem<Value>
  ) -> Result<Void, TheError>
  where Value: Codable {
    do {
      return try save(
        jsonEncoder.encode(JSONWrapper(value)),
        item.identifier
      )
    } catch {
      return .failure(.keychain(errSecInvalidData))
    }
  }
}

private let keychainShareGroupIdentifier: String = "UHX38H22ZT.com.passbolt.mobile"
private let keychainBiometricsTimeout: TimeInterval = 0 // require biometrics each time

private func biometricsContext() -> LAContext {
  let context: LAContext = .init()
  context.touchIDAuthenticationAllowableReuseDuration = keychainBiometricsTimeout
  return context
}

private struct JSONWrapper<Value: Codable>: Codable {
  
  // data stored in keychain has a size limit,
  // stored data length can be reduced by using short identifier i.e. 'v'
  // swiftlint:disable identifier_name
  fileprivate var v: Value
  // swiftlint:enable identifier_name
  
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
) -> Result<Data, TheError> {
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ?? true
  else { return .failure(.keychain(errSecNotAvailable)) }
  return loadKeychainKeyQuery(using: key, tag: tag, in: context)
    .flatMap { query in
      var queryResult: AnyObject?
      let status: OSStatus = SecItemCopyMatching(
        query,
        &queryResult
      )
      guard status == errSecSuccess
      else { return .failure(.keychain(status)) }
      
      guard
        let existingItem = queryResult as? [String: AnyObject],
        let data = existingItem[kSecValueData as String] as? Data
      else { return .failure(.keychain(errSecDataNotAvailable)) }
      return .success(data)
    }
}

@inline(__always)
private func saveKeychain(
  data: Data,
  for key: String,
  tag: String?,
  in context: LAContext? = nil
) -> Result<Void, TheError> {
  guard context?.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ?? true
  else { return .failure(.keychain(errSecNotAvailable)) }
  switch loadKeychainData(for: key, tag: tag, in: context) {
  case .success:
    return updateKeychainKeyQuery(using: key, tag: tag, in: context)
      .flatMap { query in
        updateKeychainKeyAttributes(for: data)
        .flatMap { attributes in
          let status: OSStatus = SecItemUpdate(
            query,
            attributes
          )
          guard status == errSecSuccess
          else { return .failure(.keychain(status)) }
          return .success(Void())
        }
      }
    
  case .failure:
    return saveKeychainKeyQuery(for: data, using: key, tag: tag, in: context)
      .flatMap { query in
        let status: OSStatus = SecItemAdd(
          query,
          nil
        )
        guard status == errSecSuccess
        else { return .failure(.keychain(status)) }
        return .success(Void())
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
      else { return .failure(.keychain(status)) }
      return .success(Void())
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
    kSecMatchLimit: kSecMatchLimitOne,
    kSecReturnAttributes: kCFBooleanTrue as Any,
    kSecReturnData: kCFBooleanTrue as Any,
    kSecAttrAccount: key
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  } else { /* */ }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrLabel] = tag
  } else { /* */ }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .userPresence,
        &error
      ),
      error == nil
    else { return .failure(.keychain(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  } else {
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
    kSecAttrAccount: key,
    kSecValueData: data
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  } else { /* */ }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrLabel] = tag
  } else { /* */ }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .userPresence,
        &error
      ),
      error == nil
    else { return .failure(.keychain(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  } else {
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
    kSecAttrAccount: key
  ]
  if !keychainShareGroupIdentifier.isEmpty {
    query[kSecAttrAccessGroup] = keychainShareGroupIdentifier
  } else { /* */ }
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrLabel] = tag
  } else { /* */ }
  if let context: LAContext = context {
    var error: Unmanaged<CFError>?
    guard
      let acl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .userPresence,
        &error
      ),
      error == nil
    else { return .failure(.keychain(errSecParam)) }
    query[kSecAttrAccessControl] = acl
    query[kSecUseAuthenticationContext] = context
  } else {
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
    kSecAttrAccount: key
  ]
  if let tag: String = tag, !tag.isEmpty {
    query[kSecAttrLabel] = tag
  } else { /* */ }
  return .success(query as CFDictionary)
}

#if DEBUG
extension Keychain {
  
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      verifyBiometricsPermission: Commons.placeholder("You have to provide mocks for used methods"),
      load: Commons.placeholder("You have to provide mocks for used methods"),
      save: Commons.placeholder("You have to provide mocks for used methods"),
      delete: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
