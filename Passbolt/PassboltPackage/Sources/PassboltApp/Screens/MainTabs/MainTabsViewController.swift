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

import DatabaseOperations
import Display
import FeatureScopes
import SessionData

internal final class MainTabsViewController: ViewController {

  typealias Context = SessionScope.Context

  internal struct ViewState: Equatable {

    internal var isOTPTabAvailable: Bool = false
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let features: Features

  internal let navigationStateRegistry: NavigationStateRegistry
  internal let rootNavigationState: RootNavigationState
  internal let homeController: HomeViewController
  internal let settingsController: MainSettingsViewController
  internal let otpController: OTPResourcesListViewController

  internal init(context: Context, features: Features) throws {
    self.features =
      try features
      .branch(
        scope: AccountScope.self,
        context: context.account
      )
      .branch(scope: SessionScope.self, context: context)

    self.navigationStateRegistry = try self.features.instance()
    let rootNavigation: RootNavigation = try self.features.instance()
    self.rootNavigationState = rootNavigation.state

    self.viewState = .init(
      initial: .init()
    )

    self.homeController = try self.features.instance()
    self.settingsController = try self.features.instance()
    let otpFeatures: Features = try self.features.branch(scope: OTPResourcesTabScope.self)
    self.otpController = try otpFeatures.instance()
    self.configureAppearance()
  }

  private func configureAppearance() {
    let fontAttributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.inter(ofSize: 12, weight: .semibold)
    ]

    if #available(iOS 26, *) {
      let appearance: UITabBarAppearance = UITabBarAppearance()
      appearance.stackedLayoutAppearance.normal.titleTextAttributes = fontAttributes
      appearance.stackedLayoutAppearance.selected.titleTextAttributes = fontAttributes
      UITabBar.appearance().standardAppearance = appearance
    }
    else {
      let appearance: UITabBarAppearance = UITabBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = .passboltBackground
      appearance.shadowColor = .clear
      appearance.shadowImage = UIImage()
      appearance.stackedLayoutAppearance.normal.titleTextAttributes = fontAttributes
      appearance.stackedLayoutAppearance.selected.titleTextAttributes = fontAttributes
      UITabBar.appearance().standardAppearance = appearance
      UITabBar.appearance().scrollEdgeAppearance = appearance
    }
  }

  @Sendable internal func activate() async {
    if await otpTabAvailable() == true {
      viewState.update(\.isOTPTabAvailable, to: true)
    }
    await consumingErrors {
      guard let destination = await self.initialModal() else { return }
      switch destination {
      case .biometrics:
        let navigationToBiometricsSetup: NavigationToBiometricsSetup? = try self.features.instance()
        await navigationToBiometricsSetup?
          .performCatching()

      case .autofillSetup:
        let navigationToExtensionSetup: NavigationToExtensionSetup? = try self.features.instance()
        await navigationToExtensionSetup?
          .performCatching(
            context: .init(allowSkipping: true)
          )
      }
    }
  }

  func otpTabAvailable() async -> Bool {
    do {
      let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

      let sessionData: SessionData = try features.instance()
      let resourcesCountFetchDatabaseOperation: ResourcesCountFetchDatabaseOperation = try features.instance()
      let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try features.instance()
      try await sessionData.refreshIfNeeded()
      // If a user has access to otp resources just show
      // them regardless of feature flag
      let count: Int = try await resourcesCountFetchDatabaseOperation(ResourceSpecification.Slug.allTOTPTypes)
      guard count == 0
      else { return true }
      // if there is no otp resource yet, check the flag
      guard sessionConfiguration.resources.totpEnabled
      else { return false }
      // finally check if resource type is available
      let availableResourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()
      return
        availableResourceTypes
        .contains { $0.specification.slug == .totp }
    }
    catch {
      error.logged()
      return false
    }
  }

  func initialModal() async -> ModalPresentation? {
    do {
      let accountDetails: AccountDetails = try features.instance()

      Diagnostics.logger.info("Updating account profile data...")
      try await accountDetails.updateProfile()
      Diagnostics.logger.info("...account profile data updated!")
    }
    catch {
      error
        .logged(
          info: .message("...account profile data update failed!")
        )
    }
    do {
      let accountInitialSetup: AccountInitialSetup = try features.instance()
      let unfinishedSetupElements: Set<AccountInitialSetup.SetupElement> =
        await accountInitialSetup.unfinishedSetupElements()

      if unfinishedSetupElements.contains(.biometrics) {
        return .biometrics
      }
      else if unfinishedSetupElements.contains(.autofill) {
        return .autofillSetup
      }
      else {
        return .none
      }
    }
    catch {
      // Can fail only when dependency resolution fails
      error.logged()
      return .none
    }
  }

  internal enum ModalPresentation {

    case biometrics
    case autofillSetup
  }
}
