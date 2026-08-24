//
// Passbolt - Open source password manager for teams
// Copyright (c) 2026 Passbolt SA
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

import SnapshotTestsSupport

@testable import UICommons

/// Previews from `UICommons` enrolled in snapshot testing.
///
/// Coverage is opt-in: a preview is covered only once named here, and naming the type means
/// renaming or deleting one is a compile error rather than a vanishing test.
///
/// Main-actor isolated because `SnapshotPreview` stores a non-`Sendable` `@MainActor` view builder.
@MainActor
internal enum UICommonsPreviews {

  private static let module: String = "UICommons"

  internal static var all: Array<SnapshotPreview> {
    fitted.map { .of($0, module: module, layout: .fitted) }
      + fittedWidth.map { .of($0, module: module, layout: .fittedWidth) }
      + device.map { .of($0, module: module, layout: .device) }
  }

  /// Icon-sized components with a size of their own. Anything wider belongs in `fittedWidth`.
  private static let fitted: Array<any PreviewProvider.Type> = [
    AsyncToggle_Previews.self,
    AvatarButton_Previews.self,
    AvatarView_Previews.self,
    AsyncUserAvatarView_Previews.self,
    BackButton_Previews.self,
    CountdownCircleView_Previews.self,
    FingerprintTextView_Previews.self,
    IconButton_Previews.self,
    ImageWithPadding_Previews.self,
    ResourceIconView_Previews.self,
    SelectionIndicator_Previews.self,
    UserAvatarView_Previews.self,
  ]

  /// Components that span the width they are given. The default when unsure: `.fitted` fails for
  /// these, while a width costs a view that did not need one nothing.
  private static let fittedWidth: Array<any PreviewProvider.Type> = [
    // Buttons — stretch to fill their container.
    AsyncButton_Previews.self,
    LinkButton_Previews.self,
    PrimaryButton_Previews.self,
    SecondaryButton_Previews.self,

    // `LinearProgressBar` is a `GeometryReader` under `.frame(maxWidth: .infinity)` — no width.
    LinearProgressBar_Previews.self,
    ListDividerView_Previews.self,
    ListRowTitleView_Previews.self,
    ListRowTitleWithSubtitleView_Previews.self,
    ListRowView_Previews.self,
    SelectionListView_Previews.self,

    // `EntropyView` has the same shape; the field views wrap `TextField`.
    EntropyView_Previews.self,
    FormPickerFieldView_Previews.self,
    SecureFormTextFieldView_Previews.self,

    // Drawer menu
    DrawerMenuItemView_Previews.self,

    // Folders
    FolderListItemView_Previews.self,
    FolderLocationView_Previews.self,
    FolderNameView_Previews.self,

    // Messages
    WarningView_Previews.self,

    // OTP
    OTPValueView_Previews.self,
    TOTPValueView_Previews.self,

    // Permissions
    PermissionAvatarsView_Previews.self,
    ResourcePermissionTypeCompactView_Previews.self,
    ResourcePermissionTypeView_Previews.self,

    // Resources
    ResourceFieldHeaderView_Previews.self,
    ResourceListAddView_Previews.self,
    ResourceListItemView_Previews.self,
    ResourceRelativeDateView_Previews.self,

    // Search
    SearchView_Previews.self,

    // Settings
    SettingsActionRowView_Previews.self,
    SettingsItemRowView_Previews.self,

    // Tags
    CompactTagsStackView_Previews.self,
    ResourceDetailsTagListItemView_Previews.self,
    TagListItemView_Previews.self,

    // Users and user groups
    ResourceUserGroupListItemView_Previews.self,
    UserGroupListRowView_Previews.self,
    UserListRowView_Previews.self,
  ]

  /// Screen-level previews, four images each: views that fill a screen, roots that are a
  /// `List`/`ScrollView` (no ideal height), and layouts built from `Spacer()`s (ideal length zero).
  private static let device: Array<any PreviewProvider.Type> = [
    AuthorizationView_Previews.self,
    CommonList_Previews.self,
    CommonListResourceView_Previews.self,
    CommonPlainList_Previews.self,
    DetailsSectionView_Previews.self,
    DrawerMenu_Previews.self,
    EmptyListView_Previews.self,
    EmptyListViewCustomMessage_Previews.self,
    FormLongFieldView_Previews.self,
    FormTextFieldView_Previews.self,
    // Spacer-distributed content with a button on the bottom edge.
    OperationResultView_Previews.self,
    OperationResultViewSuccess_Previews.self,
  ]
}
