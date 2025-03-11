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

import Resources
import NetworkOperations
import struct Foundation.Date
import struct Foundation.Data
import class Foundation.JSONEncoder

extension EncryptedSessionKeyBundle {

  public static var mock_1: Self = .init(
    id: .init(uuidString: "5c3b6c3f-9c2d-4b2b-8c3e-7f1b8b9b2b0e")!,
    userId: .mock_ada,
    data: .init(rawValue: composeSessionKeyData()),
    createdAt: .now,
    modifiedAt: .now
  )
}

extension EncryptedSessionKeysCache {

  public static var mock_1: Self = .init(
    id: .init(uuidString: "5c3b6c3f-9c2d-4b2b-8c3e-7f1b8b9b2b0e")!,
    modifiedAt: .now,
    data: .init(rawValue: composeSessionKeyData())
  )
}

private func composeSessionKeyData() -> String {

  let resourceId: Resource.ID = .mock_1
  let sessionKey: SessionKeyData = .init(
    foreignModel: .resource,
    foreignId: .init(uuidString: resourceId.rawValue.rawValue.uuidString)!,
    sessionKey: "sessionKey",
    modified: .now
  )

  let wrapper: SessionKeyDataWrapper = .init(sessionKeys: [sessionKey])

  let encoder: JSONEncoder = .init()
  encoder.dateEncodingStrategy = .iso8601
  let data: Data = try! encoder.encode(wrapper)
  return .init(data: data, encoding: .utf8)!
}

private struct SessionKeyDataWrapper: Encodable {

  fileprivate let objectType: MetadataObjectType = .sessionKeys
  fileprivate let sessionKeys: Array<SessionKeyData>

  private enum CodingKeys: String, CodingKey {

    case objectType = "object_type"
    case sessionKeys = "session_keys"
  }
}

fileprivate struct SessionKeyData: Encodable {

  fileprivate let foreignModel: MetadataKeysService.ForeignModel
  fileprivate let foreignId: PassboltID
  fileprivate let sessionKey: String
  fileprivate let modified: Date?

  private enum CodingKeys: String, CodingKey {

    case foreignModel = "foreign_model"
    case foreignId = "foreign_id"
    case sessionKey = "session_key"
    case modified
  }
}
