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

import CommonModels
import Crypto
import Shared
import TestExtensions

@testable import Display
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class AdvancedPasswordGenerationViewControllerTests: FeaturesTestCase {

  private let configuration: Variable<PasswordPoliciesDSV> = .init(initial: .default)
  /// Number of times `SecretGenerator.generate` was invoked; drives the monotonic stub below.
  private let generateCallCount: CriticalState<Int> = .init(0)
  private let savedConfiguration: CriticalState<PasswordPoliciesDSV?> = .init(.none)
  private let revertCalled: CriticalState<Bool> = .init(false)

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    // Each call returns a distinct value so a regenerated secret can never accidentally
    // equal a previously produced preview.
    let generateCallCount: CriticalState<Int> = self.generateCallCount
    patch(
      \SecretGenerator.generate,
      with: { @Sendable _ in
        let count: Int = generateCallCount.get() + 1
        generateCallCount.set(count)
        return "generated-secret-\(count)"
      }
    )

    patch(
      \PasswordService.configuration,
      with: always(self.configuration.asAnyUpdatable())
    )
    let savedConfiguration: CriticalState<PasswordPoliciesDSV?> = self.savedConfiguration
    patch(
      \PasswordService.updateConfiguration,
      with: { @Sendable(configuration: PasswordPoliciesDSV) in
        savedConfiguration.set(configuration)
      }
    )

    let revertCalled: CriticalState<Bool> = self.revertCalled
    patch(
      \NavigationToAdvancedPasswordGeneration.mockRevert,
      with: { @Sendable _ in
        revertCalled.set(true)
      }
    )
  }

  private func makeContext(
    onSaveGenerated: @escaping @Sendable (String) async -> Void = { _ in }
  ) -> AdvancedPasswordGenerationViewController.Context {
    .init(onSaveGenerated: onSaveGenerated)
  }

  func test_configurationChange_regeneratesPreview_fromSecretGenerator() async throws {
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(context: makeContext())

    tested.commitChange()

    let preview: String = await tested.viewState.current.preview
    XCTAssertTrue(preview.hasPrefix("generated-secret-"))
  }

  // Mirrors Android `AdvancedSecretGenerationViewModel.savePreferences`: the committed value is the
  // one the user saw in the preview, never a secret regenerated while accepting.
  func test_saveConfiguration_forwardsPreviewedSecret() async throws {
    let saved: CriticalState<String?> = .init(.none)
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(
      context: makeContext(onSaveGenerated: { (value: String) in saved.set(value) })
    )

    tested.commitChange()
    let preview: String = tested.stateSnapshot.preview
    XCTAssertFalse(preview.isEmpty)

    await tested.saveConfiguration()

    XCTAssertEqual(saved.get(), preview)
  }

  func test_saveConfiguration_persistsConfiguration_andRevertsNavigation() async throws {
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(context: makeContext())

    tested.commitChange()
    let snapshotConfiguration: PasswordPoliciesDSV = tested.stateSnapshot.configuration
    await tested.saveConfiguration()

    XCTAssertEqual(self.savedConfiguration.get(), snapshotConfiguration)
    XCTAssertTrue(self.revertCalled.get())
  }

  // Unconditional commit is intentional (MOB-4729): pressing "Save" applies the previewed secret
  // even when the configuration was not edited, matching Android.
  func test_saveConfiguration_commitsPreview_evenWhenConfigurationNotEdited() async throws {
    let saved: CriticalState<String?> = .init(.none)
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(
      context: makeContext(onSaveGenerated: { (value: String) in saved.set(value) })
    )

    // Preview produced by the initial configuration only - no user edit in between.
    let preview: String = await tested.viewState.current.preview
    XCTAssertFalse(preview.isEmpty)

    await tested.saveConfiguration()

    XCTAssertEqual(saved.get(), preview)
    XCTAssertTrue(self.revertCalled.get())
  }

  func test_saveEnabled_isFalse_beforeFirstPreviewIsProduced() throws {
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(context: makeContext())

    XCTAssertTrue(tested.stateSnapshot.preview.isEmpty)
    XCTAssertFalse(tested.stateSnapshot.saveEnabled)
  }

  // Android returns from `savePreferences` without any side effect when the preview is empty;
  // committing an empty secret would wipe the password already present in the form.
  func test_saveConfiguration_doesNothing_whenPreviewIsEmpty() async throws {
    let saved: CriticalState<String?> = .init(.none)
    let tested: AdvancedPasswordGenerationViewController = try self.testedInstance(
      context: makeContext(onSaveGenerated: { (value: String) in saved.set(value) })
    )

    await tested.saveConfiguration()

    XCTAssertNil(saved.get())
    XCTAssertNil(self.savedConfiguration.get())
    XCTAssertFalse(self.revertCalled.get())
  }
}
