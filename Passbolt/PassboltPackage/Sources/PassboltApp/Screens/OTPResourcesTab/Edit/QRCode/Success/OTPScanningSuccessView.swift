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

import Display
import UICommons

internal struct OTPScanningSuccessView: ControlledView {

  private let controller: OTPScanningSuccessController

  internal init(
    controller: OTPScanningSuccessController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 8) {

      Spacer(minLength: 40)

      Image(named: .successMark)

      Text(displayable: "otp.scanning.success.title")
        .multilineTextAlignment(.center)
        .font(
          .inter(
            ofSize: 24,
            weight: .bold
          )
        )
        .foregroundColor(.passboltPrimaryText)
        .padding(top: 24)

      Spacer(minLength: 40)

      PrimaryButton(
        title: "otp.scanning.success.create.button.title",
        action: self.controller.createStandaloneOTP
      )

      #warning("[MOB-1094] Disabled until allowing resource with OTP")
      //      SecondaryButton(
      //        title: "otp.scanning.success.link.button.title",
      //        action: self.controller.updateExistingResource
      //      )
    }
    .padding(
      top: 8,
      leading: 16,
      bottom: 16,
      trailing: 8
    )
    .navigationBarBackButtonHidden(true)
  }
}
