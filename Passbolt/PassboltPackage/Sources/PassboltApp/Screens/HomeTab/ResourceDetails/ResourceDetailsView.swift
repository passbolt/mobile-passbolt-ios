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

  internal let controller: ResourceDetailsViewController

  private struct IconProps {
    static let bagdeWidth: CGFloat = 32
    static let bagdeHeight: CGFloat = 32
    static let paddingExpiredIcon: CGFloat = 65
    static let padddingExpiredIconWithFavorite: CGFloat = 33
  }

  internal init(
    controller: ResourceDetailsViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    self.contentView
      .toolbar {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
          IconButton(
            iconName: .more,
            action: self.controller.showMenu
          )
          .accessibility(identifier: "resource.details.more.button")
        }
      }
      .backgroundColor(.passboltBackground)
      .foregroundColor(.passboltPrimaryText)
      .onDisappear(perform: self.controller.coverAllFields)
  }

  @MainActor @ViewBuilder private var contentView: some View {
    CommonList {
      self.headerSectionView
      with(\.containsUndefinedFields) { (containsUndefinedFields: Bool) in
        if containsUndefinedFields {
          self.undefinedContentSectionView
        }
      }
      self.fieldsSectionsView
      CommonListSpacer(minHeight: 16)
    }
    .edgesIgnoringSafeArea(.bottom)
  }

  @MainActor @ViewBuilder private var undefinedContentSectionView: some View {
    CommonListSection {
      CommonListRow {
        WarningView(message: "resource.detail.undefined.content.warning")
      }
    }
  }

  @MainActor @ViewBuilder private var headerSectionView: some View {
    CommonListSection {
      CommonListRow {
        with(\.name) { (name: String) in
          with(\.isExpired) { isExpired in
            VStack(spacing: 8) {
              with(\.favorite) { (favorite: Bool) in
                ZStack(alignment: .topTrailing) {
                  LetterIconView(text: name)
                    .padding(
                      top: 16,
                      leading: favorite
                        ? 16
                        : 0
                    )
                  VStack {
                    if favorite {
                      Image(named: .starFilled)
                        .foregroundColor(.passboltSecondaryOrange)
                        .frame(
                          width: IconProps.bagdeWidth,
                          height: IconProps.bagdeHeight
                        )
                    }
                    // else nothing

                    if isExpired == true {
                      Image(named: .exclamationMark)
                        .resizable()
                        .frame(
                          width: 18,
                          height: 18
                        )
                        .padding(
                          .top,
                          favorite ? IconProps.padddingExpiredIconWithFavorite : IconProps.paddingExpiredIcon
                        )
                    }
                  }
                  .alignmentGuide(.trailing) { dim in
                    dim[HorizontalAlignment.center]
                  }
                  // else nothing
                }
              }
              HStack {
                Text(name)
                  .text(
                    font: .inter(
                      ofSize: 24,
                      weight: .semibold
                    ),
                    color: .passboltPrimaryText
                  )
                  .lineLimit(1)
                if isExpired == true {
                  Text(displayable: "resource.expiry.expired")
                    .text(
                      font: .inter(
                        ofSize: 24,
                        weight: .regular
                      ),
                      color: .passboltPrimaryText
                    )
                }
                // else nothing
              }
              .multilineTextAlignment(.center)
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
  }

  @MainActor @ViewBuilder private var fieldsSectionsView: some View {
    withEach(\.sections) { (section: ResourceDetailsSectionViewModel) in
      CommonListSection {
        Text(displayable: section.title)
          .font(.inter(ofSize: 16, weight: .bold))
          .padding(.bottom, 16)
        Group {
          ForEach(section.fields) { (fieldModel: ResourceDetailsFieldViewModel) in
            rowView(for: fieldModel, hideTitles: (section.fields.count + section.virtualFields.count) == 1)
          }
          ForEach(section.virtualFields) { (virtualField: ResourceDetailsSectionViewModel.VirtualField) in
            virtualFieldView(for: virtualField)
              .padding(.horizontal, 16)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.passboltBackgroundGray)
        .cornerRadius(4)
      }
      CommonListSpacer(minHeight: 8)
    }
    with(\.permissions) { (permissions: Array<OverlappingAvatarStackView.Item>) in
      CommonListSection {
        Text(displayable: "resource.detail.section.permissions")
          .font(.inter(ofSize: 16, weight: .bold))
          .padding(.bottom, 16)
        CommonListRow(
          contentAction: self.controller.showPermissionsDetails,
          content: {
            ResourceFieldView(
              name: nil,
              content: {
                OverlappingAvatarStackView(permissions)
                  .frame(height: 40)
              }
            )
          },
          accessory: DisclosureIndicatorImage.init
        )
      }
      CommonListSpacer(minHeight: 8)
    }
  }

  private func createAction(
    for action: ResourceDetailsFieldViewModel.Action,
    path: ResourceType.FieldPath
  ) -> () async throws -> Void {
    switch action {
    case .copy:
      return { () async throws -> Void in
        await self.controller.copyFieldValue(path: path)
      }

    case .reveal:
      return { () async throws -> Void in
        await self.controller.revealFieldValue(path: path)
      }

    case .hide:
      return { () async throws -> Void in
        self.controller.coverFieldValue(path: path)
      }
    }
  }

  @MainActor @ViewBuilder private func rowView(
    for fieldModel: ResourceDetailsFieldViewModel,
    hideTitles: Bool
  ) -> some View {
    CommonListRow(
      contentAction: fieldModel.mainAction.map { createAction(for: $0, path: fieldModel.path) },
      content: {
        self.fieldView(for: fieldModel, hideTitles: hideTitles)
          .padding(.leading, 16)
      },
      accessoryAction: fieldModel.accessoryAction.map { createAction(for: $0, path: fieldModel.path) },
      accessory: {
        Group {
          switch fieldModel.accessoryAction {
          case .copy:
            CopyButtonImage()
              .accessibilityIdentifier("copy.button.\(fieldModel.name.string())")

          case .reveal:
            RevealButtonImage()
              .accessibilityIdentifier("reveal.button.\(fieldModel.name.string())")

          case .hide:
            CoverButtonImage()
              .accessibilityIdentifier("hide.button.\(fieldModel.name.string())")

          case .none:
            EmptyView()
          }
        }
        .padding(.trailing, 16)
      }
    )
  }

  @MainActor @ViewBuilder private func virtualFieldView(
    for virtualField: ResourceDetailsSectionViewModel.VirtualField
  ) -> some View {
    switch virtualField {
    case .location(let location):
      CommonListRow(
        contentAction: self.controller.showLocationDetails,
        content: {
          ResourceFieldView(
            name: "resource.detail.section.location",
            content: {
              FolderLocationView(locationElements: location)
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )

    case .tags(let tags):
      CommonListRow(
        contentAction: self.controller.showTagsDetails,
        content: {
          ResourceFieldView(
            name: "resource.detail.section.tags",
            content: {
              CompactTagsView(tags: tags)
            }
          )
        },
        accessory: DisclosureIndicatorImage.init
      )
    case .expiration(let isExpired, let expiryFormat):
      CommonListRow(
        content: {
          ResourceFieldView(
            name: "resource.detail.section.expiry",
            content: {
              ResourceRelativeDateView(viewModel: expiryFormat.viewModel(isExpired: isExpired))
            }
          )
        }
      )
    }
  }

  @MainActor @ViewBuilder private func fieldView(
    for fieldModel: ResourceDetailsFieldViewModel,
    hideTitles: Bool
  ) -> some View {
    ResourceFieldView(
      name: hideTitles ? nil : fieldModel.name,
      content: {
        switch fieldModel.value {
        case .plain(let value):
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
            .accessibilityIdentifier("text.encrypted.\(fieldModel.name.string())")

        case .password(let value):
          // password has specific font to be displayed
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

        case .encryptedTOTP:
          TOTPValueView(value: .none)

        case .totp(hash: _, let generateTOTP):
          AutoupdatingTOTPValueView(generateTOTP: generateTOTP)

        case .placeholder(let value):
          Text(value)
            .text(
              .leading,
              lines: .none,
              font: .interItalic(
                ofSize: 12,
                weight: .regular
              ),
              color: .passboltSecondaryText
            )

        case .invalid(let error):
          Text(displayable: error.displayableMessage)
            .text(
              .leading,
              lines: .none,
              font: .interItalic(
                ofSize: 14,
                weight: .regular
              ),
              color: .passboltSecondaryRed
            )
        }
      }
    )
  }

}

extension RelativeDateDisplayableFormat {
  fileprivate func viewModel(isExpired: Bool) -> ResourceRelativeDateViewModel {
    ResourceRelativeDateViewModel(
      relativeDate: localizedRelativeString,
      intervalNumber: number,
      pastDatePrefix: "resource.detail.section.expiry.expired",
      futureDatePrefix: "resource.detail.section.expiry.willExpire",
      isPastDate: isExpired
    )
  }
}
