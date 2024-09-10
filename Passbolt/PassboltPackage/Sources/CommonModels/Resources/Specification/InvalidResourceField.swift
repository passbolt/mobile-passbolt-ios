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

public struct InvalidResourceField: TheError {

  public static func error(
    _ message: StaticString,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context:
        .context(
          .message(
            message,
            file: file,
            line: line,
            details: [
              specification.name.displayable.string().lowercased(): [
                message: displayable.string()
              ]
            ]
          )
        )
        .recording(specification.name, for: "name")
        .recording(value, for: "value"),
      displayableMessage: displayable,
      specification: specification,
      path: path
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
  public var specification: ResourceFieldSpecification
  public var path: Resource.FieldPath
}

extension InvalidResourceField: Hashable {

  public static func == (
    _ lhs: InvalidResourceField,
    _ rhs: InvalidResourceField
  ) -> Bool {
    lhs.path == rhs.path
      && lhs.specification == rhs.specification
      && lhs.displayableMessage.string() == rhs.displayableMessage.string()
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.path)
  }
}

extension InvalidResourceField {

  public static func required(
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "required",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.empty",
        arguments: [
          specification.name.displayable.string()
        ]
      )
    )
  }

  public static func type(
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "type",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.content.invalid",
        arguments: [
          specification.name.displayable.string()
        ]
      )
    )
  }

  public static func minimum(
    of min: Double,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "minimum",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.range.greater",
        arguments: [
          specification.name.displayable.string(),
          min,
        ]
      )
    )
  }

  public static func maximum(
    of max: Double,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "maximum",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.range.lower",
        arguments: [
          specification.name.displayable.string(),
          max,
        ]
      )
    )
  }

  public static func minimum(
    of min: Int,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "minimum",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.range.greater",
        arguments: [
          specification.name.displayable.string(),
          min,
        ]
      )
    )
  }

  public static func maximum(
    of max: Int,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "maximum",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.range.lower",
        arguments: [
          specification.name.displayable.string(),
          max,
        ]
      )
    )
  }

  public static func minimumLength(
    of min: Int,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "minLength",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.length.higher",
        arguments: [
          specification.name.displayable.string(),
          min,
        ]
      )
    )
  }

  public static func maximumLength(
    of max: Int,
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "maxLength",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.length.lower",
        arguments: [
          specification.name.displayable.string(),
          max,
        ]
      )
    )
  }

  public static func notListed(
    specification: ResourceFieldSpecification,
    path: Resource.FieldPath,
    value: JSON,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      "notListed",
      specification: specification,
      path: path,
      value: value,
      displayable: .localized(
        key: "error.resource.field.selection.invalid",
        arguments: [
          specification.name.displayable.string()
        ]
      )
    )
  }
}
