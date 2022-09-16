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

public struct OverlappingAvatarStackView: View {

  private let items: Array<Item>

  public init(
    _ items: Array<Item>
  ) {
    self.items = items
  }

  public var body: some View {
    GeometryReader { geometry in
      let itemSize: CGFloat = geometry.size.height
      let (itemsCount, reminderCount, spacing): (Int, Int, CGFloat) = {
        let minimumItemWidth: CGFloat = geometry.size.height * 0.5
        let maximumWidth: CGFloat = geometry.size.width

        var itemsCount: Int = 0
        var reminderCount: Int = self.items.count
        var spacing: CGFloat = 8
        var tempItemWidth: CGFloat = itemSize

        while reminderCount > 0 {
          let proposedWidth: CGFloat = CGFloat(itemsCount + 1) * (tempItemWidth + max(0, spacing))

          // next item fits
          if proposedWidth < maximumWidth {
            itemsCount += 1
            reminderCount -= 1
            continue
          }
          // next item does not fit, lower spacing
          else if spacing >= 0 {
            spacing -= 0.5
            continue
          }
          // next item does not fit, lower spacing and item width for stacking
          else if tempItemWidth > minimumItemWidth {
            spacing -= 1
            tempItemWidth -= 1
            continue
          }
          // no more items can fit, make room for reminder count
          else {
            itemsCount -= 1
            reminderCount += 1
            break
          }
        }

        return (
          max(0, itemsCount),
          max(0, reminderCount),
          spacing
        )
      }()

      HStack(spacing: spacing) {
        ForEach(self.items.prefix(itemsCount)) { item in
          switch item {
          case let .user(_, avatarImage: avatarImage):
            AsyncUserAvatarView(imageLoad: avatarImage)
              .frame(width: itemSize, height: itemSize)

          case .userGroup:
            UserGroupAvatarView()
              .frame(width: itemSize, height: itemSize)
          }
        }

        if reminderCount >= 100 {
          AvatarView {
            Text("99+")
              .text(
                font: .inter(ofSize: 14, weight: .semibold),
                color: .passboltTertiaryText
              )
              .frame(width: itemSize, height: itemSize)
          }
        }
        else if reminderCount > 0 {
          AvatarView {
            Text("\(reminderCount)")
              .text(
                font: .inter(ofSize: 14, weight: .semibold),
                color: .passboltTertiaryText
              )
              .frame(width: itemSize, height: itemSize)
          }
        }  // else { /* NOP */ }
      }
    }
  }
}

extension OverlappingAvatarStackView {

  public enum Item {

    case user(User.ID, avatarImage: () async -> Data?)
    case userGroup(UserGroup.ID)
  }
}

extension OverlappingAvatarStackView.Item: Hashable {

  public static func == (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    switch (lhs, rhs) {
    case let (.user(lid, _), .user(rid, _)):
      return lid == rid

    case let (.userGroup(lid), .userGroup(rid)):
      return lid == rid

    case _:
      return false
    }
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    switch self {
    case let .user(id, _):
      hasher.combine(id)

    case let .userGroup(id):
      hasher.combine(id)
    }
  }
}

extension OverlappingAvatarStackView.Item: Identifiable {

  public var id: AnyHashable {
    switch self {
    case let .user(id, _):
      return id

    case let .userGroup(id):
      return id
    }
  }
}

#if DEBUG

extension OverlappingAvatarStackView.Item: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<OverlappingAvatarStackView.Item> {
    zip(
      with: { (id: String, bool: Bool) in
        if bool {
          return .user(
            .init(rawValue: id),
            avatarImage: Generator<Data?>.randomAvatarImage(using: randomnessGenerator).next
          )
        }
        else {
          return .userGroup(.init(rawValue: id))
        }
      },
      UUID.randomGenerator(using: randomnessGenerator)
        .map(\.uuidString),
      Bool
        .randomGenerator(using: randomnessGenerator)
    )
  }
}

internal struct OverlappingAvatarStackView_Previews: PreviewProvider {

  internal static var previews: some View {
    VStack {
      OverlappingAvatarStackView(
        (0...3)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...7)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...8)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...9)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...12)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...16)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...17)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...18)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...24)
          .map { _ in .random() }
      )
      .frame(height: 40)

      OverlappingAvatarStackView(
        (0...200)
          .map { _ in .random() }
      )
      .frame(height: 40)
    }
    .backgroundColor(.white)
    .padding(2)
    .backgroundColor(.green)
  }
}
#endif
