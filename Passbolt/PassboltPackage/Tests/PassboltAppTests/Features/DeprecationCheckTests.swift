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
import Features
import OSFeatures
import TestExtensions
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class DeprecationCheckTests: LoadableFeatureTestCase<DeprecationCheck>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltDeprecationCheck()
  }

  var silencedNotices: CriticalState<Array<String>?>!

  override func prepare() throws {
    self.silencedNotices = .init(.none)
    let silencedNotices: CriticalState<Array<String>?> = self.silencedNotices
    patch(
      \SilencedDeprecationNoticesStoredProperty.variable,
      with: .init(
        fetch: { silencedNotices.get() },
        store: { (value: Array<String>?) in
          silencedNotices.set(value)
        }
      )
    )
  }

  override func cleanup() throws {
    self.silencedNotices = .none
  }

  func test_pendingNotice_isNone_whenSystemVersionIsSupported() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion)  // supported
    )

    let feature: DeprecationCheck = try testedInstance()

    XCTAssertNil(feature.pendingNotice())
  }

  func test_pendingNotice_isProvided_whenSystemVersionIsDeprecated() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()

    XCTAssertNotNil(feature.pendingNotice())
  }

  func test_pendingNotice_isNone_whenPendingNoticeWasSilenced() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.silence(notice)

    XCTAssertNil(feature.pendingNotice())
  }

  func test_pendingNotice_isNone_whenPendingNoticeWasAlreadyPresented() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.markPresented(notice)

    XCTAssertNil(feature.pendingNotice())
  }

  func test_markPresented_doesNotSilencePendingNotice() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.markPresented(notice)

    // withholding lasts only for the application run - nothing is persisted
    XCTAssertNil(self.silencedNotices.get())
  }

  func test_pendingNotice_isProvided_whenOnlyOtherNoticeWasSilenced() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )
    self.silencedNotices.set(["some-already-silenced-notice"])

    let feature: DeprecationCheck = try testedInstance()

    XCTAssertNotNil(feature.pendingNotice())
  }

  func test_pendingNotice_isProvided_whenSilencedForPreviousRequirement() async throws {
    let previousRequirement: Int = DeprecationCheck.upcomingMinimumSystemVersion - 1
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(previousRequirement - 1)  // deprecated
    )
    self.silencedNotices.set(["system-support-\(previousRequirement)"])

    let feature: DeprecationCheck = try testedInstance()

    XCTAssertNotNil(feature.pendingNotice())
  }

  func test_silence_storesNoticeIdentifier() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.silence(notice)

    XCTAssertEqual(
      self.silencedNotices.get(),
      [notice.identifier]
    )
  }

  func test_silence_keepsPreviouslySilencedNotices() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )
    self.silencedNotices.set(["some-already-silenced-notice"])

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.silence(notice)

    XCTAssertEqual(
      self.silencedNotices.get(),
      ["some-already-silenced-notice", notice.identifier]
    )
  }

  func test_silence_doesNotStoreSameNoticeTwice() async throws {
    patch(
      \ApplicationMeta.operatingSystemMajorVersion,
      with: always(DeprecationCheck.upcomingMinimumSystemVersion - 1)  // deprecated
    )

    let feature: DeprecationCheck = try testedInstance()
    let notice: DeprecationNotice = try XCTUnwrap(feature.pendingNotice())

    feature.silence(notice)
    feature.silence(notice)

    XCTAssertEqual(
      self.silencedNotices.get(),
      [notice.identifier]
    )
  }
}
