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

import Combine
import UICommons

public final class TransferInfoScreenView: ScrolledStackView {

  internal var tapButtonPublisher: AnyPublisher<Void, Never> { button.tapPublisher }

  private let headerLabel: Label = .init()
  private let stepLabels: Array<Label> = .init()
  private let imageView: ImageView = .init()
  private let button: TextButton = .init()

  override public func setup() {

    mut(headerLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .textColor(dynamic: .primaryText),
        .text(localized: "transfer.account.description")
      )
    }

    func icon(number: Int) -> Label {
      Mutation<Label>
        .combined(
          .widthAnchor(.equalTo, constant: 24),
          .heightAnchor(.equalTo, constant: 24),
          .cornerRadius(12),
          .border(width: 1, color: .gray),
          .font(.inter(ofSize: 14, weight: .semibold)),
          .textColor(dynamic: .primaryText),
          .textAlignment(.center),
          .text("\(number)")
        )
        .instantiate()
    }

    let firstStep: StepListItemView = .init()
    mut(firstStep) {
      .combined(
        .iconView(icon(number: 1)),
        .label(
          mutatation: .attributedString(
            .localized(
              "transfer.account.info.step.first",
              font: .inter(
                ofSize: 14,
                weight: .regular
              ),
              color: .secondaryText
            )
          )
        )
      )
    }

    let secondStep: StepListItemView = .init()
    mut(secondStep) {
      .combined(
        .iconView(icon(number: 2)),
        .label(
          mutatation: .attributedString(
            .localized(
              "transfer.account.info.step.second",
              withBoldSubstringLocalized: "transfer.account.info.step.second.distinct",
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let thirdStep: StepListItemView = .init()
    mut(thirdStep) {
      .combined(
        .iconView(icon(number: 3)),
        .label(
          mutatation: .attributedString(
            .localized(
              "transfer.account.info.step.third",
              withBoldSubstringLocalized: "transfer.account.info.step.third.distinct",
              fontSize: 14,
              color: .secondaryText
            )
          )
        )
      )
    }

    let fourthStep: StepListItemView = .init()
    mut(fourthStep) {
      .combined(
        .iconView(icon(number: 4)),
        .label(
          mutatation: .attributedString(
            .localized(
              "transfer.account.info.step.fourth",
              font: .inter(
                ofSize: 14,
                weight: .regular
              ),
              color: .secondaryText
            )
          )
        )
      )
    }

    let stepListView: StepListView = .init()
    mut(stepListView) {
      .steps(
        firstStep,
        secondStep,
        thirdStep,
        fourthStep
      )
    }

    let imageContainer: ContainerView = .init(
      contentView: imageView,
      mutation: .combined(
        .image(dynamic: .qrCodeSample),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, imageView.heightAnchor)
      ),
      widthMultiplier: 0.6,
      heightMultiplier: 1
    )

    mut(button) {
      .combined(
        .primaryStyle(),
        .text(localized: "transfer.account.scan.qr.button"),
        .accessibilityIdentifier("button.transfer.account")
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 24, left: 16, bottom: 16, right: 16)),
        .append(headerLabel),
        .appendSpace(of: 24),
        .append(stepListView),
        .appendSpace(of: 16),
        .append(imageContainer),
        .appendFiller(minSize: 16),
        .append(button)
      )
    }
  }
}

