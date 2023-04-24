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
import Features

// MARK: - Interface

public struct OTPEditForm {

  public var updates: UpdatesSequence
  public var state: @Sendable () -> State
  public var fillFromURI: @Sendable (String) throws -> Void
  public var update: @Sendable (Assignment<State>) -> Void
  public var sendForm: @Sendable (SendFormAction) async throws -> Void

  public init(
    updates: UpdatesSequence,
    state: @escaping @Sendable () -> State,
    fillFromURI: @escaping @Sendable (String) throws -> Void,
    update: @escaping @Sendable (Assignment<State>) -> Void,
    sendForm: @escaping @Sendable (SendFormAction) async throws -> Void
  ) {
    self.updates = updates
    self.state = state
    self.fillFromURI = fillFromURI
    self.update = update
    self.sendForm = sendForm
  }
}

extension OTPEditForm {

  public struct State: Hashable {

    public enum OTPType: Hashable {

      case hotp(counter: Validated<UInt64>)
      case totp(period: Validated<Seconds>)

      public var counter: Validated<UInt64?> {
        get {
          switch self {
          case .hotp(let counter):
            return counter.toOptional()

          case .totp:
            return .valid(.none)
          }
        }
        set {
          guard let newValue = newValue.fromOptional()
          else { return }  // Can't assign .none
          self = .hotp(counter: newValue)
        }
      }

      public var period: Validated<Seconds?> {
        get {
          switch self {
          case .hotp:
            return .valid(.none)

          case .totp(let period):
            return period.toOptional()
          }
        }
        set {
          guard let newValue = newValue.fromOptional()
          else { return }  // Can't assign .none
          self = .totp(period: newValue)
        }
      }
    }

    public var name: Validated<String>
    public var uri: Validated<String>
    public var secret: Validated<String>
    public var algorithm: Validated<HOTPAlgorithm>
    public var digits: Validated<UInt>
    public var type: OTPType

    public init(
      name: Validated<String> = .valid(""),
      uri: Validated<String> = .valid(""),
      secret: Validated<String> = .valid(""),
      algorithm: Validated<HOTPAlgorithm> = .valid(.sha1),
      digits: Validated<UInt> = .valid(6),
      type: OTPType = .totp(period: .valid(30))
    ) {
      self.name = name
      self.uri = uri
      self.secret = secret
      self.algorithm = algorithm
      self.digits = digits
      self.type = type
    }
  }

  public func update<Value>(
    field keyPath: WritableKeyPath<State, Value>,
    to value: Value
  ) {
    self.update(.assigning(value, to: keyPath))
  }

  public func update<Value>(
    field keyPath: WritableKeyPath<State, Validated<Value>>,
    toValidated value: Value
  ) {
    self.update(.assigning(value, toValidated: keyPath))
  }
}

extension OTPEditForm: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  public enum SendFormAction {

    case createStandalone
    case attach(to: Resource.ID)
  }

  #if DEBUG
  public static var placeholder: Self {
    .init(
      updates: .placeholder,
      state: unimplemented0(),
      fillFromURI: unimplemented1(),
      update: unimplemented1(),
      sendForm: unimplemented1()
    )
  }
  #endif
}
