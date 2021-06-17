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

import AegithalosCocoa

public final class StepListView: View {
  
  public required init() {
    super.init()
    
    mut(self) {
      .backgroundColor(.clear)
    }
  }
  
  public func set(steps: Array<StepListItemView>) {
    subviews.forEach { $0.removeFromSuperview() } // remove previous views
    var iterator: Array<StepListItemView>.Iterator = steps.makeIterator()
    var predecessorAnchor: NSLayoutYAxisAnchor = topAnchor
    var currentStep: StepListItemView? = iterator.next()
    while let step: StepListItemView = currentStep {
      mut(step) {
        .combined(
          .subview(of: self),
          .leadingAnchor(.equalTo, leadingAnchor),
          .trailingAnchor(.equalTo, trailingAnchor),
          .topAnchor(.equalTo, predecessorAnchor, constant: 8)
        )
      }
      predecessorAnchor = step.bottomAnchor
      if let nextStep: StepListItemView = iterator.next() {
        let divider: View = .init()
        mut(divider) {
          .combined(
            .backgroundColor(dynamic: .divider),
            .subview(of: self),
            .heightAnchor(.equalTo, constant: 16),
            .widthAnchor(.equalTo, constant: 1),
            .topAnchor(.equalTo, predecessorAnchor, constant: 8),
            .leadingAnchor(.equalTo, leadingAnchor, constant: 12)
          )
        }
        predecessorAnchor = divider.bottomAnchor
        currentStep = nextStep
      } else {
        mut(step) {
          .bottomAnchor(.equalTo, bottomAnchor, constant: -8)
        }
        currentStep = nil
      }
    }
  }
}

extension Mutation where Subject: StepListView {
  
  public static func steps(_ steps: StepListItemView...) -> Self {
    .custom { (subject: Subject) in
      subject.set(steps: steps)
    }
  }
}
