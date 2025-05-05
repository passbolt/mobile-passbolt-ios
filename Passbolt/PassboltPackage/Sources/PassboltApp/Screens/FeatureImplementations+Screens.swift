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
import SharedUIComponents

extension FeaturesRegistry {

  public mutating func useLiveNavigation() {
    // MARK: - Global
    self.useLiveNavigationToLogs()
    self.useLiveNavigationToOperationAuthorization()
    self.useLiveNavigationToExternalActivity()
    self.useLiveNavigationToOperationResult()
    self.useLiveNavigationToTransferInfo()

    // MARK: - Session
    self.useLiveNavigationToAccountMenu()
    self.useLiveNavigationToAuthorization()
    self.useLiveNavigationToAccountDetails()
    self.useLiveNavigationToManageAccounts()

    // MARK: - Resource details
    self.useLiveNavigationToResourceDetails()
    self.useLiveNavigationToResourceLocationDetails()
    self.useLiveNavigationToResourceTagsDetails()
    self.useLiveNavigationToResourcePermissionsDetails()

    // MARK: - Resource menu
    self.useLiveNavigationToResourceContextualMenu()
    self.useLiveNavigationToResourceDeleteAlert()
    self.useLiveNavigationToResourceShare()
    self.useLiveNavigationToResourceEdit()
    self.useLiveNavigationToResourceCreateMenu()

    // MARK: - OTP Tab
    self.useLiveNavigationToOTPResourcesTab()
    self.useLiveNavigationToOTPResourcesList()

    // MARK: - OTP menu
    self.useLiveNavigationToResourceOTPContextualMenu()
    self.useLiveNavigationToResourceOTPDeleteAlert()

    // MARK: - OTP create menu
    self.useLiveNavigationToResourceOTPEditMenu()
    self.useLiveNavigationToOTPScanning()
    self.useLiveNavigationToOTPScanningSuccess()
    self.useLiveNavigationToOTPEditForm()
    self.useLiveNavigationToOTPEditAdvancedForm()

    // MARK: - Resource Edit
    self.useLiveNavigationToResourceTextEdit()
    self.useLiveNavigationToOTPAttachSelectionList()
    self.useLiveNavigationToResourcePasswordEdit()

    // MARK: - Settings Tab
    self.useLiveNavigationToTroubleshootingSettings()
    self.useLiveNavigationToTermsAndLicensesSettings()
    self.useLiveNavigationToApplicationSettings()
    self.useLiveNavigationToDefaultPresentationModeSettings()
    self.useLiveNavigationToAutofillSettings()
    self.useLiveNavigationToAccountsSettings()
    self.useLiveNavigationToAccountExport()
    self.useLiveNavigationToAccountKeyInspector()
    self.useLiveNavigationToAccountKeyExportMenu()
  }
}
