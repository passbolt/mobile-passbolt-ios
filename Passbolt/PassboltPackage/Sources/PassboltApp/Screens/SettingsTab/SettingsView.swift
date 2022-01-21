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

import UICommons

internal final class SettingsView: ScrolledStackView {

  internal var autofillTapPublisher: AnyPublisher<Void, Never> { autoFillItem.tapPublisher }
  internal var manageAccountsTapPublisher: AnyPublisher<Void, Never> { manageAccountsItem.tapPublisher }
  internal var termsTapPublisher: AnyPublisher<Void, Never> { termsItem.tapPublisher }
  internal var privacyPolicyTapPublisher: AnyPublisher<Void, Never> { privacyPolicyItem.tapPublisher }
  internal var signOutTapPublisher: AnyPublisher<Void, Never> { signOutItem.tapPublisher }
  internal var biometricsTapPublisher: AnyPublisher<Void, Never> { biometricsToggle.tapPublisher }
  internal var logsTapPublisher: AnyPublisher<Void, Never> { logsItem.tapPublisher }

  private let biometricsItem: SettingsItemView = .init()
  private let biometricsSwitch: UISwitch = .init()
  private let biometricsToggle: Button = .init()
  private let autoFillItem: SettingsItemView = .init()
  private let manageAccountsItem: SettingsItemView = .init()
  private let termsItem: SettingsItemView = .init()
  private let privacyPolicyItem: SettingsItemView = .init()
  private let logsItem: SettingsItemView = .init()
  private let signOutItem: SettingsItemView = .init()

  @available(*, unavailable, message: "Use init(termsHidden:privacyPolicyHidden:)")
  required internal init() {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  internal init(termsHidden: Bool, privacyPolicyHidden: Bool) {
    super.init()

    mut(biometricsToggle) {
      .combined(
        .backgroundColor(.clear)
      )
    }

    mut(biometricsSwitch) {
      .combined(
        .userInteractionEnabled(false),
        .subview(of: biometricsToggle),
        .edges(
          equalTo: biometricsToggle,
          insets: .init(top: 0, left: 0, bottom: 0, right: -3)
        )
      )
    }

    mut(biometricsItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { [weak self] (subject: SettingsItemView) in
          guard let self = self else { return }
          subject.add(
            accessory: self.biometricsToggle,
            with: .init(top: 0, left: 0, bottom: 0, right: 18)
          )
        }
      )
    }

    mut(autoFillItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .key, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.autofill")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(manageAccountsItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .people, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.manage.accounts")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(termsItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .info, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.terms")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(privacyPolicyItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .lockedLock, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.privacy.policy")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(logsItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .bug, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.logs")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(signOutItem) {
      .combined(
        .backgroundColor(dynamic: .background),
        .custom { (subject: SettingsItemView) in
          subject.applyOn(icon: .image(named: .exit, from: .uiCommons))
          subject.applyOn(label: .text(displayable: .localized(key: "account.settings.sign.out")))
          subject.addDisclosureIndicator()
        }
      )
    }

    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .isLayoutMarginsRelativeArrangement(true),
        .contentInset(.init(top: 16, left: 0, bottom: 0, right: 0)),
        .append(biometricsItem),
        .append(autoFillItem),
        .append(manageAccountsItem),
        .when(
          !termsHidden,
          then: .append(termsItem)
        ),
        .when(
          !privacyPolicyHidden,
          then: .append(privacyPolicyItem)
        ),
        .append(logsItem),
        .append(signOutItem),
        .appendFiller(minSize: 20)
      )
    }
  }

  internal func applyOn(biometricsImage mutation: Mutation<ImageView>) {
    biometricsItem.applyOn(icon: mutation)
  }

  internal func applyOn(biometricsLabel mutation: Mutation<Label>) {
    biometricsItem.applyOn(label: mutation)
  }

  internal func applyOn(biometricsSwitch mutation: Mutation<UISwitch>) {
    mutation.apply(on: biometricsSwitch)
  }

  internal func applyOn(biometricsToggle mutation: Mutation<Button>) {
    mutation.apply(on: biometricsToggle)
  }

  internal func setAutoFill(hidden: Bool) {
    mut(autoFillItem) {
      .hidden(hidden)
    }
  }
}
