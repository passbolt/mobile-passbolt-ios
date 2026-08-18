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

  public typealias Configuration = PasswordPoliciesDSV

  fileprivate static let minimumEntropy: Entropy = .fairPassword

  public var generate: @Sendable () async throws -> String
  public var entropy: @Sendable (String) async -> Entropy
  public var validate: @Sendable (String) async throws -> SecretValidationResult
  public var configuration: @Sendable () -> AnyUpdatable<Configuration>
  public var updateConfiguration: @Sendable (Configuration) async -> Void

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
      validate: unimplemented1(),
      configuration: unimplemented0(),
      updateConfiguration: unimplemented1()
    )
  }
  #endif

  @MainActor public static func load(
    using features: Features
  ) throws -> PasswordService {

    let passwordPoliciesLoader: PasswordPoliciesLoader = try features.instance()
    let secretsGenerator: SecretGenerator = try features.instance()
    let pwnedPasswordsChecker: PwnedPasswordChecker = try features.instance()

    // Locally overridden configuration, assigned from the advanced generation screen.
    // When unset the server (or default) policies are used.
    let override: Variable<Configuration?> = .init(initial: .none)
    let resolved: ComputedVariable<Configuration> = .init(transformed: override) {
      (update: Update<Configuration?>) async throws -> Configuration in
      if let overridden: Configuration = try update.value {
        return overridden
      }
      return await passwordPoliciesLoader.policies()
    }

    @Sendable
    func currentConfiguration() async -> Configuration {
      do {
        return try await resolved.value
      }
      catch {
        error.logged()
        return await passwordPoliciesLoader.policies()
      }
    }

    @Sendable func updateConfiguration(_ newConfiguration: Configuration) async {
      override.assign(newConfiguration)
    }

    @Sendable
    func generate() async throws -> String {
      let configuration: Configuration = await currentConfiguration()
      return try secretsGenerator.generate(configuration)
    }

    @Sendable
    func entropy(for secret: String) async -> Entropy {
      let configuration: Configuration = await currentConfiguration()
      return secretsGenerator.entropy(secret, configuration)
    }

    @Sendable func validate(_ secret: String) async throws -> SecretValidationResult {
      let configuration: Configuration = await currentConfiguration()
      let entropy: Entropy = secretsGenerator.entropy(secret, configuration)
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
      validate: validate,
      configuration: { resolved.asAnyUpdatable() },
      updateConfiguration: updateConfiguration(_:)
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
      in: ResourceEditScope.self
    )
  }
}
