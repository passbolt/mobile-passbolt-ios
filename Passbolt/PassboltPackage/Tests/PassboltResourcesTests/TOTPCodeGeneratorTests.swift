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

import Accounts
import SessionData
import TestExtensions
import XCTest

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class TOTPCodeGeneratorTests: LoadableFeatureTestCase<TOTPCodeGenerator> {

  let secret: String = "AABBCCDD"

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltTOTPCodeGenerator()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_generation_period30_digits6_withTime0() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 30,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period30_digits6_withTime1() {
    patch(
      \OSTime.timestamp,
      with: always(1)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 29,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period30_digits6_withTime15() {
    patch(
      \OSTime.timestamp,
      with: always(15)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 15,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period30_digits6_withTime29() {
    patch(
      \OSTime.timestamp,
      with: always(29)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 1,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period30_digits6_withTime30() {
    patch(
      \OSTime.timestamp,
      with: always(30)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 30,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period30_digits8_withTime0() {
    patch(
      \OSTime.timestamp,
      with: always(1)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 8
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "12345678",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "12345678",
        timeLeft: 29,
        period: 30
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 8,
					period: 30
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period10_digits6_withTime0() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 10,
        period: 10
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 10
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period10_digits6_withTime1() {
    patch(
      \OSTime.timestamp,
      with: always(1)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 9,
        period: 10
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 10
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period10_digits6_withTime9() {
    patch(
      \OSTime.timestamp,
      with: always(9)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 1,
        period: 10
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 10
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }

  func test_generation_period10_digits6_withTime10() {
    patch(
      \OSTime.timestamp,
      with: always(10)
    )
    patch(
      \HOTPCodeGenerator.generate,
      context: .init(
        resourceID: .mock_1,
        sharedSecret: self.secret,
        algorithm: .sha1,
        digits: 6
      ),
      with: always(
        .init(
          resourceID: .mock_1,
          otp: "123456",
          counter: 0
        )
      )
    )
    withTestedInstanceReturnsEqual(
      TOTPValue(
        resourceID: .mock_1,
        otp: "123456",
        timeLeft: 10,
        period: 10
      ),
      context: .init(
        resourceID: .mock_1,
				totpSecret: .init(
					sharedSecret: self.secret,
					algorithm: .sha1,
					digits: 6,
					period: 10
				)
      )
    ) { (feature: TOTPCodeGenerator) in
      feature.generate()
    }
  }
}
