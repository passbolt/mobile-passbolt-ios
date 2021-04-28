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
import Gopenpgp

public struct PGP {
  // The following functions accept private & public keys as PGP formatted strings
  // https://pkg.go.dev/github.com/ProtonMail/gopenpgp/v2#readme-documentation
  
  // Encrypt and sign
  public var encryptAndSign: (
    _ input: String, _ passphrase: String, _ privateKey: String, _ publicKey: String
  ) -> Result<String, TheError>
  // Decrypt and verify signature
  public var decryptAndVerify: (
    _ input: String, _ passphrase: String, _ privateKey: String, _ publicKey: String
  ) -> Result<String, TheError>
  // Encrypt without signing
  public var encrypt: (_ input: String, _ key: String) -> Result<String, TheError>
  // Decrypt without verifying signature
  public var decrypt: (_ input: String, _ passphrase: String, _ privateKey: String) -> Result<String, TheError>
  // Sign cleartext message
  public var signMessage: (_ input: String, _ passphrase: String, _ privateKey: String) -> Result<String, TheError>
  // Verify cleartext message
  public var verifyMessage: (_ input: String, _ publicKey: String, _ verifyTime: Int64) -> Result<String, TheError>
  // Verify if passhrase is correct
  public var verifyPassphrase: (_ key: String, _ passphrase: String) -> Result<Void, TheError>
}

extension PGP {
  // swiftlint:disable cyclomatic_complexity
  public static func gopenPGP() -> Self {
    .init(
      encryptAndSign: { input, passphrase, privateKey, publicKey in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        guard let passphraseData: Data = passphrase.data(using: .utf8) else {
          return .failure(.invalidPassphraseError())
        }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperEncryptSignMessageArmored(
          publicKey, privateKey, passphraseData, input, &error
        )
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      decryptAndVerify: { input, passphrase, privateKey, publicKey in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        guard let passphraseData: Data = passphrase.data(using: .utf8) else {
          return .failure(.invalidPassphraseError())
        }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperDecryptVerifyMessageArmored(
          publicKey, privateKey, passphraseData, input, &error
        )
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      encrypt: { input, key in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperEncryptMessageArmored(key, input, &error)
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      decrypt: { input, passphrase, privateKey in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        guard let passphraseData: Data = passphrase.data(using: .utf8) else {
          return .failure(.invalidPassphraseError())
        }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperDecryptMessageArmored(privateKey, passphraseData, input, &error)
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      signMessage: { input, passphrase, privateKey in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        guard let passphraseData: Data = passphrase.data(using: .utf8) else {
          return .failure(.invalidPassphraseError())
        }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperSignCleartextMessageArmored(privateKey, passphraseData, input, &error)
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      verifyMessage: { input, publicKey, verifyTime in
        guard !input.isEmpty else {
          return .failure(.invalidInputDataError())
        }
        
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        var error: NSError?
        let result: String = Gopenpgp.HelperVerifyCleartextMessageArmored(publicKey, input, verifyTime, &error)
        
        guard let nsError: NSError = error else {
          return .success(result)
        }
        
        return .failure(.pgpError(nsError))
      },
      verifyPassphrase: { key, passphrase in
        defer { Gopenpgp.HelperFreeOSMemory() }
        
        guard let cryptoKey: CryptoKey = Gopenpgp.CryptoKey(fromArmored: key),
              let passphraseData: Data = passphrase.data(using: .utf8) else {
          return .failure(.invalidPassphraseError())
        }
        
        do {
          _ = try cryptoKey.unlock(passphraseData)
          return .success(())
        } catch {
          return .failure(.invalidPassphraseError())
        }
      }
    )
  }
}

