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
import SwiftUI

public enum SnackBarMessage {

  case info(DisplayableString)
  case error(DisplayableString)
}

extension SnackBarMessage {

  public static func error(
    _ error: Error
  ) -> Self? {
    switch error {
    case is CancellationError, is Cancelled:
      return .none

    case let error:
      return .error(
        error
          .asTheError()
          .displayableMessage
      )
    }
  }
}

private struct SnackBar<SnackBarModel, SnackBarView>: ViewModifier
where SnackBarView: View {

  private var presenting: Binding<SnackBarModel?>
  private let autoDismissDelaySeconds: UInt64
  private let snackBar: (SnackBarModel) -> SnackBarView

  fileprivate init(
    presenting: Binding<SnackBarModel?>,
    autoDismissDelaySeconds: UInt64 = 3,
    @ViewBuilder snackBar: @escaping (SnackBarModel) -> SnackBarView
  ) {
    self.presenting = presenting
    self.autoDismissDelaySeconds = autoDismissDelaySeconds
    self.snackBar = snackBar
  }

  fileprivate func body(
    content: Content
  ) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let model: SnackBarModel = self.presenting.wrappedValue {
          snackBar(model)
            .cornerRadius(4)
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
              self.presenting.wrappedValue = nil
            }
            .task {
              guard self.autoDismissDelaySeconds > 0 else { return }
							try? await Task.sleep(seconds: self.autoDismissDelaySeconds)
							guard !Task.isCancelled else { return }
							self.presenting.wrappedValue = nil
            }  // else no snack bar
        }
      }
  }
}

extension View {

  public func snackBar<Model, SnackBarView>(
    presenting: Binding<Model?>,
    autoDismissDelaySeconds: UInt64 = 3,
    @ViewBuilder snackBar: @escaping (Model) -> SnackBarView
  ) -> some View
  where SnackBarView: View {
    ModifiedContent(
      content: self,
      modifier: SnackBar(
        presenting: presenting,
        autoDismissDelaySeconds: autoDismissDelaySeconds,
        snackBar: snackBar
      )
    )
  }

  public func snackBarMessage(
    presenting: Binding<SnackBarMessage?>,
    autoDismissDelaySeconds: UInt64 = 3
  ) -> some View {
    self.snackBar(
      presenting: presenting,
      autoDismissDelaySeconds: autoDismissDelaySeconds,
      snackBar: { message in
        switch message {
        case let .info(message):
          HStack(alignment: .center, spacing: 0) {
            Text(displayable: message)
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .font(.inter(ofSize: 14, weight: .regular))

            Image(named: .close)
              .resizable()
              .frame(width: 16, height: 16, alignment: .trailing)
              .padding(16)
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(.passboltPrimaryAlertText)
          .backgroundColor(.passboltBackgroundAlert)

        case let .error(error):
          HStack(alignment: .center, spacing: 0) {
            Text(displayable: error)
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .font(.inter(ofSize: 14, weight: .regular))

            Image(named: .close)
              .resizable()
              .frame(width: 16, height: 16, alignment: .trailing)
              .padding(16)
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(.passboltPrimaryAlertText)
          .backgroundColor(.passboltSecondaryRed)
        }
      }
    )
  }
}

extension SnackBarMessage: Hashable {}
