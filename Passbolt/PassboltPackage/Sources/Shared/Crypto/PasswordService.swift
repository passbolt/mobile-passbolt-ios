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

import Crypto
import FeatureScopes

public struct PasswordService: Sendable {

  fileprivate static let minimumEntropy: Entropy = .fairPassword

  public var generate: @Sendable () async throws -> String
  public var entropy: @Sendable (String) async -> Entropy
  public var validate: @Sendable (String) async throws -> SecretValidationResult

  public enum SecretValidationResult: Sendable {

    case valid
    case weak
    case pwned
  }
}

extension PasswordService: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: PasswordService {
    .init(
      generate: unimplemented0(),
      entropy: unimplemented1(),
      validate: unimplemented1()
    )
  }
  #endif

  @MainActor public static func load(
    using features: Features
  ) throws -> PasswordService {

    let passwordPoliciesLoader: PasswordPoliciesLoader = try features.instance()
    let secretsGenerator: SecretGenerator = try features.instance()
    let pwnedPasswordsChecker: PwnedPasswordChecker = try features.instance()

    @Sendable
    func generate() async throws -> String {
      let configuration: SecretGenerator.Configuration = await passwordPoliciesLoader.policies()
      return try secretsGenerator.generate(configuration)
    }

    @Sendable
    func entropy(for secret: String) async -> Entropy {
      let configuration: SecretGenerator.Configuration = await passwordPoliciesLoader.policies()
      return secretsGenerator.entropy(secret, configuration)
    }

    @Sendable func validate(_ secret: String) async throws -> SecretValidationResult {
      let configuration: SecretGenerator.Configuration = await passwordPoliciesLoader.policies()
      let entropy: Entropy = await entropy(for: secret)
      if entropy < Self.minimumEntropy {
        return .weak
      }

      guard configuration.externalDictionaryCheck else { return .valid }
      do {
        let isValid: Bool = try await pwnedPasswordsChecker.check(secret)
        return isValid ? .valid : .pwned
      }
      catch {
        error.logged()
        Diagnostics.logger.error("Failed to check password against pwned passwords, skipping this check")
        throw PasswordExternalCheckFailure.error().recording(error, for: "underlying_error")
      }
    }

    return .init(
      generate: generate,
      entropy: entropy(for:),
      validate: validate
    )
  }

  public struct PasswordExternalCheckFailure: TheError {

    public static func error(
      file: StaticString = #fileID,
      line: UInt = #line
    ) -> Self {
      Self(
        context: .context(
          .message(
            "Failed to validate secret against external dictionary.",
            file: file,
            line: line
          )
        )
      )
    }

    public var context: DiagnosticsContext
  }
}

extension FeaturesRegistry {

  internal mutating func usePasswordService() {
    self.use(
      .lazyLoaded(
        PasswordService.self,
        load: PasswordService.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
