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

// test data based on https://www.rfc-editor.org/rfc/rfc4226
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class HOTPCodeGeneratorTests: LoadableFeatureTestCase<HOTPCodeGenerator> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltHOTPCodeGenerator()
  }

  func test_generation_0() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "cc93cf18508d94934c64b65d8ba7667fb7cde4b0")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "755224",
        counter: 0
      )
    ) { (feature: HOTPCodeGenerator) in
      feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(0)
    }
  }

  func test_generation_1() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "75a48a19d4cbe100644e8ac1397eea747a2d33ab")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "287082",
        counter: 1
      )
    ) { (feature: HOTPCodeGenerator) in
      feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(1)
    }
  }

  func test_generation_2() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "0bacb7fa082fef30782211938bc1c5e70416ff44")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "359152",
        counter: 2
      )
    ) { (feature: HOTPCodeGenerator) in
			feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(2)
    }
  }

  func test_generation_3() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "66c28227d03a2d5529262ff016a1e6ef76557ece")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "969429",
        counter: 3
      )
    ) { (feature: HOTPCodeGenerator) in
      feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(3)
    }
  }

  func test_generation_4() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "a904c900a64b35909874b33e61c5938a8e15ed1c")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "338314",
        counter: 4
      )
    ) { (feature: HOTPCodeGenerator) in
      feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(4)
    }
  }

  func test_generation_5() {
    patch(
      \HMAC.sha1,
      with: always(
        dataFrom(hex: "a37e783d7b7233c083d4f62926c7a25f238d0316")
      )
    )
    withTestedInstanceReturnsEqual(
      HOTPValue(
        resourceID: .mock_1,
        otp: "254676",
        counter: 5
      )
    ) { (feature: HOTPCodeGenerator) in
      feature.prepare(
				.init(
					resourceID: .mock_1,
					sharedSecret: "12345678901234567890",
					algorithm: .sha1,
					digits: 6
				)
			)(5)
    }
  }
}

private func dataFrom(
  hex string: String
) -> Data {
  string
    .split(every: 2)
    .compactMap { UInt8($0, radix: 16) }
    .reduce(into: Data()) { result, element in
      result.append(element)
    }
}
