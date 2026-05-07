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

import AccountSetup
import Accounts
import Crypto
import Dispatch
import FeatureScopes
import Foundation

extension AccountKitImport {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {

    let pgp: PGP = features.instance()
    let accounts: Accounts = try features.instance()

    /// Imports an account kit and returns the account transfer data.
    ///
    /// This function processes the provided account kit payload, performing the following steps:
    /// 1. Validates the payload format (non-empty, base64 encoded).
    /// 2. Extracts the PGP message from the payload.
    /// 3. Extracts the account kit data from the PGP message.
    /// 4. Validates the account kit signature.
    /// 5. Extracts the fingerprint from the public key.
    /// 6. Checks if the account already exists.
    /// 7. Returns the account transfer data if successful.
    ///
    /// - Parameter payload: The account kit payload to be imported (base64 encoded string).
    /// - Returns: The imported `AccountTransferData` on success.
    /// - Throws: `AccountKitImportFailure` if the payload is invalid, `AccountKitImportInvalidSignature` if the signature is invalid, `AccountKitAccountAlreadyExist` if the account already exists, or other errors encountered during import.
    @Sendable nonisolated func importAccountKit(
      _ payload: String
    ) throws -> AccountTransferData {
      Diagnostics.logger.info("Processing account kit..")
      do {
        // First, check the account kit format
        Diagnostics.logger.info("Check account kit payload format...")
        try checkAccountkitFormat(payload)

        // Extract the PGPMessage from the base64
        Diagnostics.logger.info("Extracting PGPMessage...")
        let pgpMessage = try extractPGPMessage(payload, pgp).get()

        // Extract the account kit
        Diagnostics.logger.info("Extracting account kit from PGPMessage...")
        let accountkit = try extractAccountKit(pgpMessage).get()

        Diagnostics.logger.info("Validate account kit signature...")
        //Validate the signature
        _ = try validateAccountKitSignature(pgpMessage, accountkit.publicKeyArmored, pgp).get()

        Diagnostics.logger.info("Signature validated, extract fingerprint from public key...")
        let fingerPrint = try getFingerPrint(accountkit.publicKeyArmored, pgp).get()

        //Reuse the account transfer model
        let accountTransferData = AccountTransferData(
          userID: accountkit.userID,
          domain: accountkit.domain,
          username: accountkit.username,
          firstName: accountkit.firstName,
          lastName: accountkit.lastname,
          avatarImageURL: nil,
          fingerprint: fingerPrint,
          armoredKey: accountkit.privateKeyArmored
        )

        Diagnostics.logger.info("Check if importing account does not exist")
        try checkIfAccountExist(accounts, accountTransferData)

        // Return the AccountTransferData as a successful result
        return accountTransferData
      }
      catch {
        Diagnostics.logger.info("Failed to import")
        error.logged()
        throw error
      }
    }

    return .init(
      isImportAccountKitAvailable: { true },
      importAccountKit: importAccountKit(_:)
    )
  }
}

/// Checks the format of the provided account kit payload.
///
/// Performs several checks on the payload:
/// 1. Ensures that the payload is not empty.
/// 2. Validates that the payload is in base64 format.
/// Throws an error if any check fails.
///
/// - Parameter payload: The account kit payload to validate (base64 encoded string).
/// - Throws: `AccountKitImportFailure` if the payload is empty or not base64 encoded.
private func checkAccountkitFormat(
  _ payload: String
) throws {
  //Check if the string is not empty
  guard !payload.isEmpty else {
    throw
      AccountKitImportFailure.error()
      .pushing(.message("The account kit is required."))
  }

  // Validate the base64 format
  guard Data(base64Encoded: payload) != nil else {
    throw
      AccountKitImportFailure.error()
      .pushing(.message("The account kit should be a base 64 format."))
  }
}

/// Extracts a PGP message from the provided base64 encoded payload.
///
/// Decodes the base64 encoded payload and uses the provided PGP instance to extract a PGP message.
///
/// - Parameters:
///   - payload: The base64 encoded string containing the PGP message.
///   - pgp: The PGP instance used for extracting the PGP message.
/// - Returns: A `Result` containing the PGP message string on success, or an error on failure.
private func extractPGPMessage(
  _ payload: String,
  _ pgp: PGP
) -> Result<String, Error> {
  do {
    //Extract pgpMessage from base64
    if let data = Data(base64Encoded: payload) {
      //PGPMessage as string
      let pgpMessage =
        try pgp
        .readCleartextMessage(data)
        .get()
      return .success(pgpMessage)
    }
    return .failure(
      AccountKitImportFailure.error()
        .pushing(.message("Failed to decode base64."))
    )
  }
  catch {
    return .failure(
      AccountKitImportFailure.error()
        .pushing(.message("Failed to decode PGPMessage."))
    )
  }
}

/// Extracts an Account Kit DTO (Data Transfer Object) from a provided PGP message.
///
/// Searches for a JSON string within the PGP message and attempts to decode it into an `AccountKitDTO`.
///
/// - Parameter pgpMessage: The PGP message string from which the Account Kit DTO is to be extracted.
/// - Returns: A `Result` containing the `AccountKitDTO` on success, or an error on failure.
private func extractAccountKit(
  _ pgpMessage: String
) -> Result<AccountKitDTO, Error> {
  //Map PGPMessage to account kit dto

  do {
    let pattern = "\\{.*\\}\\}"
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(pgpMessage.startIndex..., in: pgpMessage)
    if let match = regex.firstMatch(in: pgpMessage, options: [], range: range),
      let matchRange = Range(match.range, in: pgpMessage)
    {
      let accountKitJson = String(pgpMessage[matchRange])
      let accountKit =
        try JSONDecoder.default
        .decode(
          AccountKitDTO.self,
          from: Data(accountKitJson.utf8)
        )
      return .success(accountKit)
    }
  }
  catch {
    return .failure(
      AccountKitImportFailure.error()
        .pushing(.message("Cannot extract account kit from payload"))
    )
  }
  return .failure(
    AccountKitImportFailure.error()
      .pushing(.message("No Account kit found on the PGP message"))
  )
}

/// Validates the signature of an Account Kit PGP message using a provided public key.
///
/// Attempts to verify the signature of the provided PGP message using the given armored PGP public key and a PGP instance.
///
/// - Parameters:
///   - pgpMessage: The PGP message whose signature is to be validated.
///   - publicKeyArmored: The armored PGP public key used for signature verification.
///   - pgp: The PGP instance used for verifying the message signature.
/// - Returns: A `Result` containing the verification result string on success, or an error on failure.
private func validateAccountKitSignature(
  _ pgpMessage: String,
  _ publicKeyArmored: ArmoredPGPPublicKey,
  _ pgp: PGP
) -> Result<String, Error> {
  do {
    //Verify the signature through GOPENPGP
    let currentTime = Date()
    let result = try pgp.verifyMessage(pgpMessage, publicKeyArmored, Int64(currentTime.timeIntervalSince1970)).get()
    return .success(result)
  }
  catch {
    return .failure(
      AccountKitImportInvalidSignature.error()
        .pushing(.message("Failed to validate signature"))
    )
  }
}

/// Extracts the fingerprint from an armored PGP public key.
///
/// Uses a PGP instance to extract the fingerprint from the provided armored PGP public key.
///
/// - Parameters:
///   - publicKeyArmored: The armored PGP public key from which the fingerprint is to be extracted.
///   - pgp: The PGP instance used for extracting the fingerprint.
/// - Returns: A `Result` containing the `Fingerprint` on success, or an error on failure.
private func getFingerPrint(_ publicKeyArmored: ArmoredPGPPublicKey, _ pgp: PGP) -> Result<Fingerprint, Error> {
  do {
    let result = try pgp.extractFingerprint(publicKeyArmored).get()
    return .success(result)
  }
  catch {
    return .failure(
      AccountKitImportFailure.error()
        .pushing(.message("Cannot retrieve fingerprint from private key"))
    )
  }
}

/// Checks if an account already exists within the specified account import context.
///
/// Evaluates whether the account specified by the account transfer data already exists in the account import context.
///
/// - Parameters:
///   - accounts: The account import context to check for the existence of the account.
///   - accountTransferData: The account transfer data to check for existence.
/// - Throws: `AccountKitAccountAlreadyExist` if the account already exists.
private func checkIfAccountExist(
  _ accounts: Accounts,
  _ accountTransferData: AccountTransferData
) throws {

  if accounts
    .storedAccounts()
    .contains(
      where: { stored in
        stored.userID.rawValue == accountTransferData.userID
          && stored.domain == accountTransferData.domain
      }
    )
  {
    Diagnostics.debug("Skipping account transfer bypass - duplicate account")
    throw
      AccountKitAccountAlreadyExist.error()
      .pushing(.message("The account kit already exist."))
  }
}

extension FeaturesRegistry {
  mutating func usePassboltAccountKitImport() {
    self.use(
      .lazyLoaded(
        AccountKitImport.self,
        load: AccountKitImport
          .load(features:)
      ),
      in: AccountTransferScope.self
    )
  }
}
