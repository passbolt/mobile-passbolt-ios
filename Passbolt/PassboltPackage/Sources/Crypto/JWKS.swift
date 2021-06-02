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

public struct JWKS: Decodable {
  
  public enum Key {
    
    public enum Kind: String, Decodable {
      // We're supporting only RSA
      case rsa = "RSA"
    }
    
    public enum Purpose: String, Decodable {
      // We're supporting only signature
      case signature = "sig"
    }
  }
  
  public var algorithm: JWT.Algorithm
  public var keyType: Key.Kind
  public var purpose: Key.Purpose
  public var exponent: String
  public var modulus: String
  
  private enum CodingKeys: String, CodingKey {
    
    case algorithm = "alg"
    case keyType = "kty"
    case purpose = "use"
    case exponent = "e"
    case modulus = "n"
  }
}
