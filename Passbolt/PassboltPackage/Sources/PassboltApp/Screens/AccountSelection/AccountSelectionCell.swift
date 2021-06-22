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

import Accounts
import UICommons
 
internal final class AccountSelectionCell: CollectionViewCell {
  
  private let icon: ImageView = .init()
  private let titleLabel: Label = .init()
  private let subTitleLabel: Label = .init()
  private let imageButton: ImageButton = .init()
  private let stack: StackView = .init()
  private var tapAction: (() -> Void)?
  private var removeAction: (() -> Void)?
  private var cancellables: Cancellables = .init()
  
  override internal func setup() {
    super.setup()
    
    mut(self) {
      .combined(
        .backgroundColor(dynamic: .background),
        .translatesAutoresizingMaskIntoConstraints(false)
      )
    }
    
    Mutation<Button>.combined(
      .backgroundColor(.clear),
      .subview(of: contentView),
      .edges(equalTo: contentView),
      .action({ [weak self] in self?.tapAction?() })
    )
    .instantiate()
    
    mut(contentView) {
      .subview(icon, stack, imageButton)
    }
    
    mut(titleLabel) {
      .combined(
        .font(.inter(ofSize: 14, weight: .semibold)),
        .textColor(dynamic: .primaryText)
      )
    }
    
    mut(subTitleLabel) {
      .combined(
        .font(.inter(ofSize: 12)),
        .textColor(dynamic: .secondaryText)
      )
    }
  
    mut(stack) {
      .combined(
        .subview(of: contentView),
        .axis(.vertical),
        .spacing(8),
        .arrangedSubview(titleLabel, subTitleLabel),
        .topAnchor(.equalTo, contentView.topAnchor, constant: 8),
        .bottomAnchor(.equalTo, contentView.bottomAnchor, constant: -8),
        .leadingAnchor(.equalTo, icon.trailingAnchor, constant: 12),
        .trailingAnchor(.equalTo, imageButton.leadingAnchor, constant: -12)
      )
    }
    
    mut(icon) {
      .combined(
        .subview(of: contentView),
        .image(named: .person, from: .uiCommons),
        .tintColor(dynamic: .icon),
        .contentMode(.scaleAspectFit),
        .leadingAnchor(.equalTo, contentView.leadingAnchor, constant: 12),
        .trailingAnchor(.equalTo, stack.leadingAnchor, constant: -12),
        .topAnchor(.equalTo, contentView.topAnchor, constant: 12),
        .bottomAnchor(.equalTo, contentView.bottomAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 40),
        .heightAnchor(.equalTo, constant: 40)
      )
    }
    
    mut(imageButton) {
      .combined(
        .centerYAnchor(.equalTo, icon.centerYAnchor),
        .trailingAnchor(.equalTo, contentView.trailingAnchor, constant: -12),
        .widthAnchor(.equalTo, constant: 20),
        .heightAnchor(.equalTo, constant: 20),
        .contentMode(.scaleAspectFit),
        .image(named: .trash, from: .uiCommons),
        .tintColor(dynamic: .icon),
        .action { [weak self] in
          self?.removeAction?()
        }
      )
    }
  }
  
  internal func setup(
    from item: AccountSelectionCellItem,
    tapAction: @escaping (() -> Void),
    removeAction: @escaping (() -> Void)
  ) {
    titleLabel.text = item.title
    subTitleLabel.text = item.subtitle
    
    self.tapAction = tapAction
    self.removeAction = removeAction
    
    item.imagePublisher?
      .receive(on: RunLoop.main)
      .sink(receiveValue: { [weak self] imageData in
        guard let data: Data = imageData,
          let image: UIImage = .init(data: data) else {
          return
        }
        
        self?.icon.image = image
      })
      .store(in: cancellables)
    
    item.modePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] mode in
        guard let self = self else { return }
        
        UIView.animate(withDuration: 0.3) {
          self.imageButton.alpha = mode == .selection ? 0 : 1
        }
        
        mut(self.imageButton) {
          .hidden(mode == .selection)
        }
      }
      .store(in: cancellables)
  }
  
  override internal func prepareForReuse() {
    super.prepareForReuse()

    cancellables = .init()
    
    mut(icon) {
      .combined(
        .image(named: .person, from: .uiCommons)
      )
    }
    
    titleLabel.text = nil
    subTitleLabel.text = nil
    tapAction = nil
    removeAction = nil
  }
}
