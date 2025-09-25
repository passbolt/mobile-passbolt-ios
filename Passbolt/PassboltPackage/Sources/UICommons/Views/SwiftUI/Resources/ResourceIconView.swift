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

import CommonModels
import Localization
import SwiftUI

/// A view that displays custom resource icons with fallback to letter-based icons
public struct ResourceIconView: View {

  private let resourceIcon: ResourceIcon
  private let resourceTypeSlug: ResourceSpecification.Slug?

  public init(
    resourceIcon: ResourceIcon,
    resourceTypeSlug: ResourceSpecification.Slug?
  ) {
    self.resourceIcon = resourceIcon
    self.resourceTypeSlug = resourceTypeSlug
  }

  public var body: some View {
    ZStack {
      backgroundView
      resolvedIcon
        .foregroundColor(tintColor)
    }
    .frame(
      minWidth: 32,
      idealWidth: 40,
      maxWidth: 56,
      minHeight: 32,
      idealHeight: 40,
      maxHeight: 56,
      alignment: .center
    )
    .aspectRatio(1, contentMode: .fit)
  }

  @ViewBuilder
  private var resolvedIcon: some View {
    let provider: IconProvider.Type = resourceIcon.type.provider
    if let iconIdentifier: ResourceIcon.IconIdentifier = resourceIcon.value {
      provider.icon(for: iconIdentifier)?
        .resizable()
        .renderingMode(.template)
        .aspectRatio(contentMode: .fit)
    }
    else if let resourceTypeSlug = resourceTypeSlug {
      provider.icon(for: resourceTypeSlug)?
        .resizable()
        .renderingMode(.template)
        .aspectRatio(contentMode: .fit)
        .padding(8)
    }
    else {
      EmptyView()
    }
  }

  private var tintColor: Color {
    guard
      let backgroundColorString: String = resourceIcon.backgroundColor,
      let tintColor: Color = .luminance(for: .init(rawValue: backgroundColorString))
    else {
      return .white
    }

    return tintColor
  }

  private var backgroundColor: Color {
    if let backgroundColorString = resourceIcon.backgroundColor,
      let color = Color(hex: .init(rawValue: backgroundColorString))
    {
      return color
    }
    else {
      return .passboltIcon
    }
  }

  @ViewBuilder
  private var backgroundView: some View {
    Circle()
      .fill(backgroundColor)
  }
}
