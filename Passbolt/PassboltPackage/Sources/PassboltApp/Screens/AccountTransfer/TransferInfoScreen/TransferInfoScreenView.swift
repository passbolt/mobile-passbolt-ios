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
  private let firstStep: StepListItemView = .init()
  private let secondStep: StepListItemView = .init()
  private let thirdStep: StepListItemView = .init()
  private let fourthStep: StepListItemView = .init()
  private let button: TextButton = .init()

  override public func setup() {
    mut(headerLabel) {
      .combined(
        .font(.inter(ofSize: 14)),
        .textColor(dynamic: .primaryText)
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

    mut(firstStep) {
      .iconView(icon(number: 1))
    }

    mut(secondStep) {
      .iconView(icon(number: 2))
    }

    mut(thirdStep) {
      .iconView(icon(number: 3))
    }

    mut(fourthStep) {
      .iconView(icon(number: 4))
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
        .image(named: .qrCodeSample, from: .uiCommons),
        .contentMode(.scaleAspectFit),
        .widthAnchor(.equalTo, imageView.heightAnchor)
      ),
      widthMultiplier: 0.6,
      heightMultiplier: 1
    )

    mut(button) {
      .primaryStyle()
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

  internal func setupFor(
    context: TransferInfoScreenController.Context
  ) {
    switch context {
    case .import:
      mut(headerLabel) {
        .text(displayable: .localized(key: "transfer.account.import.description"))
      }
      mut(firstStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.import.info.step.first"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }

      mut(secondStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.import.info.step.second"),
                withBoldSubstring: .localized(key: "transfer.account.import.info.step.second.distinct"),
                fontSize: 14,
                color: .secondaryText
              )
            )
        )
      }
      mut(thirdStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.import.info.step.third"),
                withBoldSubstring: .localized(key: "transfer.account.import.info.step.third.distinct"),
                fontSize: 14,
                color: .secondaryText
              )
            )
        )
      }
      mut(fourthStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.import.info.step.fourth"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }
      mut(button) {
        .text(displayable: .localized(key: "transfer.account.import.scan.qr.button"))
      }
    case .export:
      mut(headerLabel) {
        .text(displayable: .localized(key: "transfer.account.export.description"))
      }
      mut(firstStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.export.info.step.first"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }
      mut(secondStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.export.info.step.second"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }
      mut(thirdStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.export.info.step.third"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }
      mut(fourthStep) {
        .label(
          mutatation:
            .attributedString(
              .displayable(
                .localized(key: "transfer.account.export.info.step.fourth"),
                font: .inter(
                  ofSize: 14,
                  weight: .regular
                ),
                color: .secondaryText
              )
            )
        )
      }
      mut(button) {
        .text(displayable: .localized(key: "transfer.account.export.scan.qr.button"))
      }
    }
  }
}
