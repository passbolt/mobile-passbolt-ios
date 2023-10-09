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

import Features

// MARK: - Interface

public typealias FeatureAccessControlConfigurationFetchNetworkOperation =
  NetworkOperation<FeatureAccessControlConfigurationFetchNetworkOperationDescription>

public enum FeatureAccessControlConfigurationFetchNetworkOperationDescription: NetworkOperationDescription {

  public typealias Output = FeatureAccessControlConfiguration
}

public struct FeatureAccessControlConfiguration: Decodable {

	public var folders: Folders
	public var tags: Tags
	public var copySecrets: CopySecrets
	public var previewSecrets: PreviewSecrets
	public var viewShareList: ViewShareList

	public init(
		folders: Folders,
		tags: Tags,
		copySecrets: CopySecrets,
		previewSecrets: PreviewSecrets,
		viewShareList: ViewShareList
	) {
		self.folders = folders
		self.tags = tags
		self.copySecrets = copySecrets
		self.previewSecrets = previewSecrets
		self.viewShareList = viewShareList
	}

	public init(
		from decoder: Decoder
	) throws {
		let accessControl: Array<FeatureAccessControlConfigurationItem> = try Array<FeatureAccessControlConfigurationItem>(from: decoder)
		
		self.folders = .decode(from: accessControl)
		self.tags = .decode(from: accessControl)
		self.copySecrets = .decode(from: accessControl)
		self.previewSecrets = .decode(from: accessControl)
		self.viewShareList = .decode(from: accessControl)
	}
}

extension FeatureAccessControlConfiguration {

	public enum Folders: FeatureAccessControlConfigurationElement {

		fileprivate static func decode(
			from accessControl: Array<FeatureAccessControlConfigurationItem>
		) -> Self {
			switch accessControl.first(where: { $0.name == "Folders.use" })?.control {
			case "Deny":
				return .deny

			case _:
				return .allow
			}
		}

		case allow
		case deny
	}

	public enum Tags: FeatureAccessControlConfigurationElement {

		fileprivate static func decode(
			from accessControl: Array<FeatureAccessControlConfigurationItem>
		) -> Self {
			switch accessControl.first(where: { $0.name == "Tags.use" })?.control {
			case "Deny":
				return .deny

			case _:
				return .allow
			}
		}

		case allow
		case deny
	}

	public enum CopySecrets: FeatureAccessControlConfigurationElement {

		fileprivate static func decode(
			from accessControl: Array<FeatureAccessControlConfigurationItem>
		) -> Self {
			switch accessControl.first(where: { $0.name == "Secrets.copy" })?.control {
			case "Deny":
				return .deny

			case _:
				return .allow
			}
		}
		
		case allow
		case deny
	}

	public enum PreviewSecrets: FeatureAccessControlConfigurationElement {

		fileprivate static func decode(
			from accessControl: Array<FeatureAccessControlConfigurationItem>
		) -> Self {
			switch accessControl.first(where: { $0.name == "Secrets.preview" })?.control {
			case "Deny":
				return .deny

			case _:
				return .allow
			}
		}
		
		case allow
		case deny
	}

	public enum ViewShareList: FeatureAccessControlConfigurationElement {

		fileprivate static func decode(
			from accessControl: Array<FeatureAccessControlConfigurationItem>
		) -> Self {
			switch accessControl.first(where: { $0.name == "Share.viewList" })?.control {
			case "Deny":
				return .deny

			case _:
				return .allow
			}
		}

		case allow
		case deny
	}
}

private protocol FeatureAccessControlConfigurationElement {

	static func decode(
		from accessControl: Array<FeatureAccessControlConfigurationItem>
	) -> Self
}

private struct FeatureAccessControlConfigurationItem: Decodable {

	fileprivate var name: String
	fileprivate var control: String

	fileprivate init(
		name: String,
		control: String
	) {
		self.name = name
		self.control = control
	}

	fileprivate init(
		from decoder: Decoder
	) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.control = try container.decode(
			String.self,
			forKey: .control
		)
		let elementContainer = try container.nestedContainer(
			keyedBy: ElementCodingKeys.self,
			forKey: .element
		)
		self.name = try elementContainer.decode(
			String.self,
			forKey: .name
		)
	}

	private enum CodingKeys: String, CodingKey {

		case control = "control_function"
		case element = "ui_action"
	}

	private enum ElementCodingKeys: String, CodingKey {

		case name = "name"
	}
}
