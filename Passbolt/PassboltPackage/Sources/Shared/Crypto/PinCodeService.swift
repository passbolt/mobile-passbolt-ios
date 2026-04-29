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
import FeatureScopes

public struct PinCodeService: Sendable {

  public var generate: @Sendable () async -> String
  public var currentConfiguration: @Sendable () async -> Configuration
  public var updateConfiguration: @Sendable (Configuration) async -> Void
}

extension PinCodeService {

  public struct Configuration: Sendable {

    public var pinCodeLength: Int

    public init(
      pinCodeLength: Int
    ) {
      self.pinCodeLength = pinCodeLength
    }
  }
}

extension PinCodeService: LoadableFeature {

  #if DEBUG
  public static var placeholder: Self {
    Self(
      generate: unimplemented0(),
      currentConfiguration: unimplemented0(),
      updateConfiguration: unimplemented1()
    )
  }
  #endif

  @MainActor public static func load(
    using features: Features
  ) throws -> PinCodeService {

    let configuration: CriticalState<Configuration> = .init(.init(pinCodeLength: 4))

    @Sendable func generate() async -> String {
      let configuration: Configuration = configuration.get()
      var result: String = ""

      for _ in 0 ..< configuration.pinCodeLength {
        let digit: Int = .random(in: 0 ... 9)
        result.append(String(digit))
      }

      return result
    }

    @Sendable func updateConfiguration(_ newConfiguration: Configuration) async {
      configuration.set(newConfiguration)
    }

    @Sendable func currentConfiguration() async -> Configuration {
      configuration.get()
    }

    return .init(
      generate: generate,
      currentConfiguration: currentConfiguration,
      updateConfiguration: updateConfiguration(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePinCodeService() {
    self.use(
      .lazyLoaded(
        PinCodeService.self,
        load: PinCodeService.load(using:)
      ),
      in: ResourceEditScope.self
    )
  }
}
