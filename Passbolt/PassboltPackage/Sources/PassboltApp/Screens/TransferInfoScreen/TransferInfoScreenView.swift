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
    
    let strings: Array<NSAttributedString> = prepareAttributedTexts()
    let steps: Array<StackView> = prepareSteps(strings: strings)
    
    let imageContainer: View = Mutation<View>
      .combined(
        .backgroundColor(dynamic: .background)
      )
      .instantiate()
    
    mut(imageView) {
      .combined(
        .subview(of: imageContainer),
        .image(dynamic: .qrCodeSample),
        .contentMode(.scaleAspectFit),
        .edges(
          equalTo: imageContainer,
          insets: .init(top: 0, left: -80, bottom: 0, right: -80)
        )
      )
    }
    
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
        .contentInset(.init(top: 24, left: 16, bottom: 8, right: 16)),
        .append(headerLabel),
        .appendSpace(of: 24),
        .append(views: steps),
        .appendSpace(of: 80),
        .append(imageContainer),
        .appendFiller(minSize: 0),
        .append(button)
      )
    }
  }
  
  private func prepareSteps(strings: Array<NSAttributedString>) -> Array<StackView> {
    strings.enumerated().map { index, attributedString in
      let verticalStack: StackView = Mutation<StackView>
        .combined(
          .axis(.vertical),
          .spacing(0)
        )
        .instantiate()
      
      let horizontalStack: StackView = Mutation<StackView>
        .combined(
          .arrangedSubview(of: verticalStack),
          .axis(.horizontal),
          .spacing(0)
        )
        .instantiate()
      
      let numberLabel: Label = Mutation<Label>
        .combined(
          .arrangedSubview(of: horizontalStack),
          .widthAnchor(.equalTo, constant: 24),
          .heightAnchor(.equalTo, constant: 24),
          .cornerRadius(12),
          .border(width: 1, color: .gray),
          .font(.inter(ofSize: 14, weight: .semibold)),
          .textColor(dynamic: .primaryText),
          .textAlignment(.center),
          .text(String(index + 1))
        )
        .instantiate()
      
      horizontalStack.appendSpace(of: 12)
      
      Mutation<Label>
        .combined(
          .arrangedSubview(of: horizontalStack),
          .attributedText(attributedString)
        )
        .instantiate()
      
      if index != strings.count - 1 {
        let divider: View = Mutation<View>
          .combined(
            .arrangedSubview(of: verticalStack),
            .backgroundColor(dynamic: .background)
          )
          .instantiate()
        
        Mutation<View>
          .combined(
            .subview(of: divider),
            .topAnchor(.equalTo, divider.topAnchor, constant: 4),
            .bottomAnchor(.equalTo, divider.bottomAnchor, constant: -4),
            .widthAnchor(.equalTo, constant: 1),
            .heightAnchor(.equalTo, constant: 16),
            .centerXAnchor(.equalTo, numberLabel.centerXAnchor),
            .backgroundColor(dynamic: .divider)
          )
          .instantiate()
      }
      
      return verticalStack
    }
  }
  
  private func prepareAttributedTexts() -> Array<NSAttributedString> {
    let texts: Array<String> = [
      "transfer.account.info.step.first",
      "transfer.account.info.step.second",
      "transfer.account.info.step.third",
      "transfer.account.info.step.fourth"
    ]
    .map {
      NSLocalizedString($0, comment: "")
    }
    
    let distinctTexts: Array<String?> = [
      nil,
      "transfer.account.info.step.second.distinct",
      "transfer.account.info.step.third.distinct",
      nil
    ]
    
    let strings: Array<NSAttributedString> = zip(texts, distinctTexts)
      .map { regular, distinct in
        let regularTextAttributes: [NSAttributedString.Key: Any] = [
          .foregroundColor: DynamicColor.secondaryText(in: traitCollection.userInterfaceStyle),
          .font: UIFont.inter(ofSize: 14)
        ]
        let boldTextAttributes: [NSAttributedString.Key: Any] = [
          .foregroundColor: DynamicColor.secondaryText(in: traitCollection.userInterfaceStyle),
          .font: UIFont.inter(ofSize: 14, weight: .bold)
        ]
        
        let string: NSMutableAttributedString = .init(
          string: regular,
          attributes: regularTextAttributes
        )
        
        if let bold: String = distinct {
          let localized: String = NSLocalizedString(bold, comment: "")
          string.apply(attributes: boldTextAttributes, to: localized)
        } else { /* */ }
        
        return string
      }
    
    return strings
  }
}
