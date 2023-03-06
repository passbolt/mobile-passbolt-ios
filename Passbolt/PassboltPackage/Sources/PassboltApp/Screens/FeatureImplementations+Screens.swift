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

extension FeaturesRegistry {

  internal mutating func useLiveScreenControllers() {
    self.usePassboltHomePresentation()

    self.useLiveDefaultPresentationModeSettingsController()
    self.useLiveResourceDetailsTagsListController()

    self.usePassboltResourcesListCreateMenuController()
    self.usePassboltResourceFolderEditController()
    self.usePassboltResourceFolderMenuController()
    self.usePassboltResourceFolderDetailsController()
    self.usePassboltResourceFolderLocationDetailsController()
    self.usePassboltResourceLocationDetailsController()
    self.usePassboltResourceFolderPermissionListController()
    self.useAccountQRCodeExportController()
    self.useAccountExportAuthorizationController()

    // MARK: - Global
    self.useLiveNavigationToLogs()

    // MARK: - Session
    self.useLiveNavigationToAccountMenu()
    self.useLiveNavigationToAuthorization()
    self.useLiveNavigationToAccountDetails()
    self.useLiveNavigationToManageAccounts()

    // MARK: - OTP Tab
    self.useLiveOTPResourcesTabController()
    self.useLiveNavigationToOTPResourcesTab()
    self.useLiveOTPResourcesListController()

    // MARK: - Create OTP
    self.useLiveCreateOTPMenuController()
    self.useLiveNavigationToCreateOTPMenu()
    self.useLiveOTPScanningController()
    self.useLiveNavigationToOTPScanning()
    self.useLiveOTPScanningSuccessController()
    self.useLiveNavigationToOTPScanningSuccess()

    // MARK: - Settings Tab
    self.useLiveMainSettingsController()
    self.useLiveTroubleshootingSettingsController()
    self.useLiveNavigationToTroubleshootingSettings()
    self.useLiveTermsAndLicensesSettingsController()
    self.useLiveNavigationToTermsAndLicensesSettings()
    self.useLiveApplicationSettingsController()
    self.useLiveNavigationToApplicationSettings()
    self.useLiveDefaultPresentationModeSettingsController()
    self.useLiveNavigationToDefaultPresentationModeSettings()
    self.useLiveNavigationToAutofillSettings()
    self.useLiveAccountsSettingsController()
    self.useLiveNavigationToAccountsSettings()
    self.useLiveNavigationToAccountExport()
  }
}
