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

public struct ResourceFieldDTO {

  public var name: ResourceFieldNameDTO
  public var valueType: ResourceFieldValueTypeDTO
  public var required: Bool
  public var encrypted: Bool
  public var maxLength: Int?

  public init(
    name: ResourceFieldNameDTO,
    valueType: ResourceFieldValueTypeDTO,
    required: Bool,
    encrypted: Bool,
    maxLength: Int?
  ) {
    self.name = name
    self.valueType = valueType
    self.required = required
    self.encrypted = encrypted
    self.maxLength = maxLength
  }
}

extension ResourceFieldDTO: DTO {}

extension ResourceFieldDTO: Decodable {

  private enum CodingKeys: String, CodingKey {

    case name = "field"
    case valueType = "type"
    case `required` = "required"
    case encrypted = "encrypted"
    case maxLength = "maxLength"
  }
}

extension ResourceFieldDTO: Hashable {}

#if DEBUG

extension ResourceFieldDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceFieldDTO.init(name:valueType:required:encrypted:maxLength:),
      ResourceFieldNameDTO.randomGenerator(using: randomnessGenerator),
      ResourceFieldValueTypeDTO.randomGenerator(using: randomnessGenerator),
      Bool.randomGenerator(using: randomnessGenerator),
      Bool.randomGenerator(using: randomnessGenerator),
      Int.randomGenerator(min: 128, max: 4096, using: randomnessGenerator)
        .optional(using: randomnessGenerator)
    )
  }
}
#endif
