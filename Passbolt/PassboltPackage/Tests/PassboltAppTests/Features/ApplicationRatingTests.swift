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

import Features
import Foundation
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class ApplicationRatingTests: LoadableFeatureTestCase<ApplicationRating> {
  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltApplicationRatingFeature()
  }

  override func prepare() throws {
    patch(
      \OSTime.timestamp,
      with: { Timestamp(rawValue: 5 * 24 * 60 * 60 + 1) }
    )
    use(OSApplicationRating.placeholder)
    use(LoginCountStoredProperty.placeholder)
    use(LastAppRateCheckTimestampStoredProperty.placeholder)
    use(ApplicationLifecycle.placeholder)
  }

  func test_applicationRating_shouldTrigger_whenCriteria_areMet() {
    patch(
      \LoginCountStoredProperty.binding,
      with: .variable(initial: 5)
    )

    patch(
      \LastAppRateCheckTimestampStoredProperty.binding,
      with: .variable(initial: 0)
    )

    patch(
      \OSApplicationRating.requestApplicationRating,
      with: always(self.executed())
    )

    withTestedInstanceExecuted(test: { (testedInstance: ApplicationRating) in
      await testedInstance.showApplicationRatingIfRequired()
    })
  }

  func test_applicationRating_shouldNotTrigger_whenAtLeastOneCriteria_isNotMet() {
    patch(
      \LoginCountStoredProperty.binding,
      with: .variable(initial: 1)
    )

    patch(
      \LastAppRateCheckTimestampStoredProperty.binding,
      with: .variable(initial: 0)
    )

    patch(
      \OSApplicationRating.requestApplicationRating,
      with: always(self.executed())
    )

    withTestedInstanceNotExecuted(test: { (testedInstance: ApplicationRating) in
      await testedInstance.showApplicationRatingIfRequired()
    })
  }

  func test_triggeredApplicationRating_shouldIncrementLoginCounter() {
    let variable: StateBinding<Int?> = StateBinding.variable(initial: 0)

    patch(
      \LoginCountStoredProperty.binding,
      with: variable
    )
    patch(
      \LastAppRateCheckTimestampStoredProperty.binding,
      with: .variable(initial: 0)
    )

    withTestedInstanceReturnsEqual(
      1,
      test: { (testedInstance: ApplicationRating) in
        await testedInstance.showApplicationRatingIfRequired()
        return variable.wrappedValue ?? 0
      }
    )
  }
}
