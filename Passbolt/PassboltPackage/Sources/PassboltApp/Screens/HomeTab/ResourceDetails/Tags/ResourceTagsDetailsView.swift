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

internal struct ResourceTagsDetailsView: ControlledView {

  internal let controller: ResourceTagsDetailsViewController

  internal init(
    controller: ResourceTagsDetailsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.contentView
      .backgroundColor(.passboltBackground)
      .foregroundColor(.passboltPrimaryText)
      .task(self.controller.activate)
  }

  @ViewBuilder @MainActor private var contentView: some View {
    CommonList {
      self.headerSectionView
      self.tagsSectionView
      CommonListSpacer(minHeight: 16)
    }
    .edgesIgnoringSafeArea(.bottom)
  }

  @MainActor @ViewBuilder private var headerSectionView: some View {
    CommonListSection {
      CommonListRow {
        VStack(spacing: 40) {
          WithViewState(
            from: self.controller,
            at: \.name
          ) { (name: String) in
            VStack(spacing: 8) {
              ZStack(alignment: .topTrailing) {
                LetterIconView(text: name)
                  .padding(top: 16)

                WithViewState(
                  from: self.controller,
                  at: \.favorite
                ) { (favorite: Bool) in
                  if favorite {
                    Image(named: .starFilled)
                      .foregroundColor(.passboltSecondaryOrange)
                      .frame(
                        width: 32,
                        height: 32
                      )
                      .alignmentGuide(.trailing) { dim in
                        dim[HorizontalAlignment.center]
                      }
                  }  // else nothing
                }
              }

              Text(name)
                .multilineTextAlignment(.center)
                .text(
                  font: .inter(
                    ofSize: 24,
                    weight: .semibold
                  ),
                  color: .passboltPrimaryText
                )
                .frame(
                  maxWidth: .infinity,
                  alignment: .center
                )
            }
          }
          .padding(
            leading: 16,
            trailing: 16
          )

          ResourceFieldHeaderView(name: "resource.detail.section.tags")
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
            .padding(bottom: 8)
        }
      }
    }
  }

  @MainActor @ViewBuilder private var tagsSectionView: some View {
    CommonListSection {
      self.tagsSectionListView
    }
  }

  @MainActor @ViewBuilder private var tagsSectionListView: some View {
    WithViewState(
      from: self.controller,
      at: \.tags
    ) { (tags: OrderedSet<ResourceTag>) in
      if tags.isEmpty {
        EmptyListView(message: "section.tags.empty")
      }
      else {
        ForEach(
          tags,
          id: \.id
        ) { item in
          CommonListRow(
            content: {
              HStack(spacing: 8) {
                Image(
                  named: item.shared
                    ? .sharedTagIcon
                    : .tagIcon
                )
                .frame(
                  width: 40,
                  height: 40,
                  alignment: .center
                )
                Text(item.slug.rawValue)
                  .text(
                    .leading,
                    lines: 1,
                    font: .inter(
                      ofSize: 14,
                      weight: .semibold
                    ),
                    color: .passboltPrimaryText
                  )
              }
              .padding(
                top: 8,
                bottom: 8
              )
            }
          )
        }
      }
    }
  }
}
