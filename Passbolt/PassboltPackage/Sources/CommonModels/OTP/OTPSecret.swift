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

public enum OTPSecret {

  case totp(
    sharedSecret: String,
    algorithm: HOTPAlgorithm,
    digits: UInt,
    period: Seconds
  )
  case hotp(
    sharedSecret: String,
    algorithm: HOTPAlgorithm,
    digits: UInt,
    counter: UInt64
  )

  public var sharedSecret: String {
    get {
      switch self {
      case .totp(let secret, _, _, _):
        return secret

      case .hotp(let secret, _, _, _):
        return secret
      }
    }
    set {
      switch self {
      case let .totp(_, algorithm, digits, period):
        self = .totp(
          sharedSecret: newValue,
          algorithm: algorithm,
          digits: digits,
          period: period
        )

      case let .hotp(_, algorithm, digits, counter):
        self = .hotp(
          sharedSecret: newValue,
          algorithm: algorithm,
          digits: digits,
          counter: counter
        )
      }
    }
  }

  public var algorithm: HOTPAlgorithm {
    get {
      switch self {
      case .totp(_, let algorithm, _, _):
        return algorithm

      case .hotp(_, let algorithm, _, _):
        return algorithm
      }
    }
    set {
      switch self {
      case let .totp(sharedSecret, _, digits, period):
        self = .totp(
          sharedSecret: sharedSecret,
          algorithm: newValue,
          digits: digits,
          period: period
        )

      case let .hotp(sharedSecret, _, digits, counter):
        self = .hotp(
          sharedSecret: sharedSecret,
          algorithm: newValue,
          digits: digits,
          counter: counter
        )
      }
    }
  }

  public var digits: UInt {
    get {
      switch self {
      case .totp(_, _, let digits, _):
        return digits

      case .hotp(_, _, let digits, _):
        return digits
      }
    }
    set {
      switch self {
      case let .totp(sharedSecret, algorithm, _, period):
        self = .totp(
          sharedSecret: sharedSecret,
          algorithm: algorithm,
          digits: newValue,
          period: period
        )

      case let .hotp(sharedSecret, algorithm, _, counter):
        self = .hotp(
          sharedSecret: sharedSecret,
          algorithm: algorithm,
          digits: newValue,
          counter: counter
        )
      }
    }
  }

  public var period: Seconds? {
    get {
      switch self {
      case .totp(_, _, _, let period):
        return period

      case .hotp(_, _, _, _):
        return .none
      }
    }
    set {
      switch self {
      case let .totp(sharedSecret, algorithm, digits, period):
        self = .totp(
          sharedSecret: sharedSecret,
          algorithm: algorithm,
          digits: digits,
          period: newValue ?? period
        )

      case .hotp:
        break
      }
    }
  }

  public var counter: UInt64? {
    get {
      switch self {
      case .totp(_, _, _, _):
        return .none

      case .hotp(_, _, _, let counter):
        return counter
      }
    }
    set {
      switch self {
      case .totp:
        break

      case let .hotp(sharedSecret, algorithm, digits, counter):
        self = .hotp(
          sharedSecret: sharedSecret,
          algorithm: algorithm,
          digits: digits,
          counter: newValue ?? counter
        )
      }
    }
  }
}

extension OTPSecret: Sendable {}
extension OTPSecret: Equatable {}
extension OTPSecret: Codable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    let sharedSecret: String = try container.decode(String.self, forKey: .sharedSecret)
    let algorithm: HOTPAlgorithm = try container.decode(HOTPAlgorithm.self, forKey: .algorithm)
    let digits: UInt = try container.decode(UInt.self, forKey: .digits)

    if let totpPeriod: Seconds = try? container.decodeIfPresent(Seconds.self, forKey: .period) {
      self = .totp(
        sharedSecret: sharedSecret,
        algorithm: algorithm,
        digits: digits,
        period: totpPeriod
      )
    }
    else if let hotpCounter: UInt64 = try? container.decodeIfPresent(UInt64.self, forKey: .counter) {
      self = .hotp(
        sharedSecret: sharedSecret,
        algorithm: algorithm,
        digits: digits,
        counter: hotpCounter
      )
    }
    else {
      throw
        DecodingError
        .dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "OTP secret has to be either TOTP or HOTP"
          )
        )
    }
  }

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .totp(sharedSecret, algorithm, digits, period):
      try container.encode(sharedSecret, forKey: .sharedSecret)
      try container.encode(algorithm, forKey: .algorithm)
      try container.encode(digits, forKey: .digits)
      try container.encode(period, forKey: .period)

    case let .hotp(sharedSecret, algorithm, digits, counter):
      try container.encode(sharedSecret, forKey: .sharedSecret)
      try container.encode(algorithm, forKey: .algorithm)
      try container.encode(digits, forKey: .digits)
      try container.encode(counter, forKey: .counter)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case sharedSecret = "key"
    case algorithm = "algorithm"
    case digits = "digits"
    case period = "period"
    case counter = "counter"
  }
}
