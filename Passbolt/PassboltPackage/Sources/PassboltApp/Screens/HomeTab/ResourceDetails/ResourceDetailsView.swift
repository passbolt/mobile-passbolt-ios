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

internal struct ResourceDetailsView: ControlledView {

  private let controller: ResourceDetailsViewController

  internal init(
    controller: ResourceDetailsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(
      from: self.controller,
      at: \.snackbarMessage
    ) { (_: SnackBarMessage?) in
      self.contentView
        .snackBarMessage(
          presenting: self.controller
            .binding(to: \.snackbarMessage)
        )
    }
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        Button(
          action: self.controller.showMenu,
          label: {
            Image(named: .more)
          }
        )
      }
    }
    .backgroundColor(.passboltBackground)
    .foregroundColor(.passboltPrimaryText)
    .task(self.controller.activate)
  }

  @MainActor @ViewBuilder private var contentView: some View {
    CommonList {
      self.headerSectionView
      self.fieldsSectionsView
      self.locationSectionView
      self.tagsSectionView
      self.permissionsSectionView
      CommonListSpacer(minHeight: 16)
    }
    .edgesIgnoringSafeArea(.bottom)
  }

  @MainActor @ViewBuilder private var headerSectionView: some View {
    CommonListSection {
      CommonListRow {
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
      }
      .padding(
        leading: 16,
        bottom: 32,
        trailing: 16
      )
    }
  }

  @MainActor @ViewBuilder private var fieldsSectionsView: some View {
    CommonListSection {
      WithViewState(
        from: self.controller,
        at: \.fields
      ) { (fields: Array<ResourceDetailsFieldViewModel>) in
        ForEach(fields) { (fieldModel: ResourceDetailsFieldViewModel) in
          CommonListRow(
            contentAction: {
              self.controller.copyFieldValue(path: fieldModel.path)
            },
            content: {
              ResourceFieldView(
                name: fieldModel.name,
                content: {
                  switch fieldModel.value {
                  case .plain(let value):
                    // password has specific font to be displayed
                    if fieldModel.path == \.secret.password || fieldModel.path == \.secret {
                      Text(value)
                        .text(
                          .leading,
                          lines: .none,
                          font: .inconsolata(
                            ofSize: 14,
                            weight: .regular
                          ),
                          color: .passboltSecondaryText
                        )
                    }
                    else {
                      Text(value)
                        .text(
                          .leading,
                          lines: .none,
                          font: .inter(
                            ofSize: 14,
                            weight: .regular
                          ),
                          color: .passboltSecondaryText
                        )
                    }

                  case .encrypted:
                    Text("••••••••")
                      .text(
                        .leading,
                        lines: 1,
                        font: .inter(
                          ofSize: 14,
                          weight: .regular
                        ),
                        color: .passboltSecondaryText
                      )
                  }
                }
              )
            },
            accessoryAction: fieldModel.accessory.map { accessory in
              switch accessory {
              case .copy:
                return {
                  self.controller.copyFieldValue(path: fieldModel.path)
                }

              case .reveal:
                return {
                  self.controller.revealFieldValue(path: fieldModel.path)
                }

              case .hide:
                return {
                  self.controller.coverFieldValue(path: fieldModel.path)
                }
              }
            },
            accessory: {
              switch fieldModel.accessory {
              case .copy:
                CopyButtonImage()

              case .reveal:
                RevealButtonImage()

              case .hide:
                CoverButtonImage()

              case .none:
                EmptyView()
              }
            }
          )
        }
      }
    }
  }

  @MainActor @ViewBuilder private var locationSectionView: some View {
    CommonListSection {
      CommonListRow(
        contentAction: self.controller.showLocationDetails,
        content: {
          ResourceFieldView(
            name: "resource.detail.section.location",
            content: {
              WithViewState(
                from: self.controller,
                at: \.location
              ) { (location: Array<String>) in
                FolderLocationView(locationElements: location)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    }
  }

  @MainActor @ViewBuilder private var tagsSectionView: some View {
    CommonListSection {
      CommonListRow(
        contentAction: self.controller.showTagsDetails,
        content: {
          ResourceFieldView(
            name: "resource.detail.section.tags",
            content: {
              WithViewState(
                from: self.controller,
                at: \.tags
              ) { (tags: Array<String>) in
                CompactTagsView(tags: tags)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    }
  }

  @MainActor @ViewBuilder private var permissionsSectionView: some View {
    CommonListSection {
      CommonListRow(
        contentAction: self.controller.showPermissionsDetails,
        content: {
          ResourceFieldView(
            name: "resource.detail.section.permissions",
            content: {
              WithViewState(
                from: self.controller,
                at: \.permissions
              ) { (permissionItems: Array<OverlappingAvatarStackView.Item>) in
                OverlappingAvatarStackView(permissionItems)
                  .frame(height: 40)
              }
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    }
  }
}
