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

import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension View {

  @ViewBuilder @MainActor public func withExternalActivity(
    _ configuration: Binding<ExternalActivityConfiguration?>
  ) -> some View {
    self.sheet(
      item: configuration,
      content: { (configuration: ExternalActivityConfiguration) in
        ExternalActivityView(with: configuration)
      }
    )
  }
}

public struct ExternalActivityConfiguration {

  public let id: ObjectIdentifier
  fileprivate let itemsConfiguration: UIActivityItemsConfiguration
  fileprivate let excludedActivities: Array<UIActivity.ActivityType>

  fileprivate init(
    itemsConfiguration: UIActivityItemsConfiguration,
    excludedActivities: Array<UIActivity.ActivityType>
  ) {
    self.itemsConfiguration = itemsConfiguration
    self.id = ObjectIdentifier(itemsConfiguration)
    self.excludedActivities = excludedActivities
  }

  public static func share(
    privateKey: ArmoredPGPPrivateKey
  ) -> Self {
    let itemProvider: NSItemProvider = .init(
      object: StringShareItem(
        privateKey: privateKey
      )
    )
    itemProvider.suggestedName = "private_key"

    let itemsConfiguration: UIActivityItemsConfiguration = .init(
      itemProviders: [itemProvider]
    )
    itemsConfiguration.metadataProvider = { (key: UIActivityItemsConfigurationMetadataKey) -> Any? in
      switch key {
      case .title:
        return "private_key"

      case _:
        return nil
      }
    }

    return .init(
      itemsConfiguration: itemsConfiguration,
      excludedActivities: {
        [
          .addToReadingList,
          .assignToContact,
          .collaborationCopyLink,
          .collaborationInviteWithLink,
          .markupAsPDF,
          .message,
          .openInIBooks,
          .saveToCameraRoll,
          .sharePlay,
          .postToVimeo,
          .postToWeibo,
          .postToFlickr,
          .postToTwitter,
          .postToFacebook,
          .postToTencentWeibo,
        ]
      }()
    )
  }

  public static func share(
    publicKey: ArmoredPGPPublicKey
  ) -> Self {
    let itemProvider: NSItemProvider = .init(
      object: StringShareItem(
        publicKey: publicKey
      )
    )
    itemProvider.suggestedName = "public_key"

    let itemsConfiguration: UIActivityItemsConfiguration = .init(
      itemProviders: [itemProvider]
    )

    itemsConfiguration.metadataProvider = { (key: UIActivityItemsConfigurationMetadataKey) -> Any? in
      switch key {
      case .title:
        return "public_key"

      case _:
        return nil
      }
    }

    return .init(
      itemsConfiguration: itemsConfiguration,
      excludedActivities: {
        [
          .addToReadingList,
          .collaborationCopyLink,
          .collaborationInviteWithLink,
          .markupAsPDF,
          .openInIBooks,
          .saveToCameraRoll,
          .sharePlay,
          .postToVimeo,
          .postToWeibo,
          .postToFlickr,
          .postToTwitter,
          .postToFacebook,
          .postToTencentWeibo,
        ]

      }()
    )
  }
}

extension ExternalActivityConfiguration: Equatable {

  public static func == (
    _ lhs: ExternalActivityConfiguration,
    _ rhs: ExternalActivityConfiguration
  ) -> Bool {
    lhs.id == rhs.id
  }
}

extension ExternalActivityConfiguration: Identifiable {}

public struct ExternalActivityView: UIViewControllerRepresentable {

  private let configuration: ExternalActivityConfiguration

  public init(
    with configuration: ExternalActivityConfiguration
  ) {
    self.configuration = configuration
  }

  public func makeUIViewController(
    context: Context
  ) -> UIActivityViewController {
    let controller: UIActivityViewController = .init(
      activityItemsConfiguration: self.configuration.itemsConfiguration
    )
    controller.excludedActivityTypes = self.configuration.excludedActivities
    return controller
  }

  public func updateUIViewController(
    _ uiViewController: UIActivityViewController,
    context: Context
  ) {
    // NOP - can't be updated
  }
}

private final class StringShareItem: NSObject, NSItemProviderWriting {

  fileprivate static let writableTypeIdentifiersForItemProvider: Array<String> = [UTType.text.identifier]

  fileprivate func loadData(
    withTypeIdentifier typeIdentifier: String,
    forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, Error?) -> Void
  ) -> Progress? {
    switch typeIdentifier {
    case UTType.text.identifier:
      completionHandler(
        self.rawString.data(using: .utf8),
        .none
      )
      return .init()
    case _:
      return .none
    }
  }

  private let rawString: String

  fileprivate init(
    privateKey: ArmoredPGPPrivateKey
  ) {
    self.rawString = privateKey.rawValue
    super.init()
  }

  fileprivate init(
    publicKey: ArmoredPGPPublicKey
  ) {
    self.rawString = publicKey.rawValue
    super.init()
  }
}
