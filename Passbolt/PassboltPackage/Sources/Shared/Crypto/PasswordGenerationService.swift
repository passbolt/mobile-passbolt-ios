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

public struct PasswordGenerationService: Sendable {

  public typealias Configuration = PasswordPoliciesDSV

  public var generate: @Sendable () async throws -> String
  public var configuration: @Sendable () -> AnyUpdatable<Configuration>
  public var updateConfiguration: @Sendable (Configuration) async -> Void
}

extension PasswordGenerationService: LoadableFeature {

  #if DEBUG
  nonisolated public static var placeholder: PasswordGenerationService {
    Self(
      generate: unimplemented0(),
      configuration: unimplemented0(),
      updateConfiguration: unimplemented1()
    )
  }
  #endif

  @MainActor public static func load(
    using features: Features
  ) throws -> PasswordGenerationService {

    let passwordPoliciesLoader: PasswordPoliciesLoader = try features.instance()
    let secretGenerator: SecretGenerator = try features.instance()

    let override: Variable<Configuration?> = .init(initial: .none)
    let resolved: ComputedVariable<Configuration> = .init(transformed: override) {
      (update: Update<Configuration?>) async throws -> Configuration in
      if let overridden: Configuration = try update.value {
        return overridden
      }
      return await passwordPoliciesLoader.policies()
    }

    @Sendable func updateConfiguration(_ newConfiguration: Configuration) async {
      override.assign(newConfiguration)
    }

    @Sendable func generate() async throws -> String {
      let configuration: Configuration = try await resolved.value
      return try secretGenerator.generate(configuration)
    }

    return .init(
      generate: generate,
      configuration: { resolved.asAnyUpdatable() },
      updateConfiguration: updateConfiguration(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePasswordGenerationService() {
    self.use(
      .lazyLoaded(
        PasswordGenerationService.self,
        load: PasswordGenerationService.load(using:)
      ),
      in: ResourceEditScope.self
    )
  }
}
