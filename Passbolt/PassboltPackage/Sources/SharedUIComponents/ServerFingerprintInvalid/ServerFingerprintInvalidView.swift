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

public struct ServerFingerprintInvalidView: ControlledView {

  public let controller: ServerFingerprintInvalidViewController

  public init(controller: ServerFingerprintInvalidViewController) {
    self.controller = controller
  }

  public var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        Image(named: .passboltLogo)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: geometry.size.width * 0.4)

        Text(displayable: "server.key.fingerprint.changed.title")
          .titleStyle()
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
          .padding(.top, 48)

        Text(displayable: "server.key.fingerprint.changed.description")
          .font(.inter(ofSize: 14))
          .lineSpacing(6)
          .foregroundStyle(Color.passboltSecondaryText)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 48)
          .padding(.top, 24)

        with(\.fingerprint) { fingerprint in
          Text(fingerprint?.formatted ?? "N/A")
            .font(.inconsolata(ofSize: 16, weight: .semibold))
            .foregroundStyle(Color.passboltPrimaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(10)
            .padding(.horizontal, 40)
            .padding(.top, 64)
        }

        with(\.newKeyAccepted) { newKeyAccepted in
          AsyncButton(
            action: {
              self.controller.checkmarkTapped()
            },
            label: {
              HStack {
                Image(
                  named: newKeyAccepted
                    ? .checked
                    : .unchecked
                )
                Text(displayable: "server.key.fingerprint.accept.check")
                  .font(.inter(ofSize: 14))
                  .foregroundStyle(Color.passboltSecondaryText)
              }
            }
          )
          .padding(.top, 80)
        }
        Spacer()
        with(\.newKeyAccepted) { newKeyAccepted in
          PrimaryButton(
            title: "server.key.fingerprint.accept.new.key",
            disabled: self.binding(to: \.newKeyAccepted).negated,
            action: {
              await self.controller.acceptNewKey()
            }
          )
          .disabled(!newKeyAccepted)
          .padding(.horizontal, 24)
        }
      }
    }
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        BackButton(action: self.controller.back)
      }
    }
  }
}

extension Fingerprint {

  fileprivate var formatted: String {
    let parts: Array<String> = stride(from: 0, to: self.rawValue.count, by: 4)
      .map {
        let startIndex = self.rawValue.index(
          self.rawValue.startIndex,
          offsetBy: $0
        )
        let endIndex =
          self.rawValue.index(
            startIndex,
            offsetBy: 4,
            limitedBy: self.rawValue.endIndex
          ) ?? self.rawValue.endIndex
        return String(self.rawValue[startIndex ..< endIndex])
      }
    // divide into two groups
    let middleIndex = parts.count / 2
    let firstLine: String = Array(parts[..<middleIndex]).joined(separator: " ")
    let secondLine: String = Array(parts[middleIndex...]).joined(separator: " ")
    return firstLine + "\n" + secondLine
  }
}

#if DEBUG
#Preview {
  PlaceholderView()
    .sheet(
      isPresented: .constant(true),
      content: {
        createPreview(
          ServerFingerprintInvalidView.self,
          with: .init(
            accountID: .ada,
            fingerprint: "A5BF F682 97CC 6D31 8XXF C298 EC69 E708 D084 CC76",
            backAction: {}
          )
        )
      }
    )
    .wrapInNavigationStack()
}
#endif
