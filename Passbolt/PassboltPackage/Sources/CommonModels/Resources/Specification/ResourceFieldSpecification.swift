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

import enum Foundation.ComparisonResult
import protocol Foundation.SortComparator
import enum Foundation.SortOrder

public struct ResourceFieldSpecification {

  public enum Content {

    case string(
      minLength: Int? = .none,
      maxLength: Int? = .none
    )
    case int(
      min: Int? = .none,
      max: Int? = .none
    )
    case double(
      min: Double? = .none,
      max: Double? = .none
    )
    case stringEnum(
      values: Array<String>
    )
    case structure(Array<ResourceFieldSpecification>)
  }

  public let path: Resource.FieldPath
  public let name: ResourceFieldName
  public let content: Content
  public let required: Bool
  public let encrypted: Bool
  public let semantics: ResourceFieldSemantics

  public init(
    path: Resource.FieldPath,
    name: ResourceFieldName,
    content: Content,
    required: Bool,
    encrypted: Bool
  ) {
    self.path = path
    self.name = name
    self.content = content
    self.required = required
    self.encrypted = encrypted
    self.semantics = {
      // we can't detect semantics of fields other way than using
      // concrete paths or exact description of complex fields
      switch content {
      case .string where path == \.secret.password || path == \.secret:
        assert(encrypted, "Unencrypted passwords should not occur!")
        return .password(
          name: name.displayable,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .string(_, .some(let maxLength)) where maxLength > 4096:
        return .longText(
          name: name.displayable,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .string:
        return .text(
          name: name.displayable,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .int:
        return .intValue(
          name: name.displayable,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .double:
        return .floatValue(
          name: name.displayable,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .stringEnum(let values):
        return .selection(
          name: name.displayable,
          values: values,
          viewingPlaceholder: name.displayableViewingPlaceholder,
          editingPlaceholder: name.displayableEditingPlaceholder
        )

      case .totp:
        assert(encrypted, "Unencrypted totp should not occur!")
        return .totp(name: name.displayable)

      case .structure:
        return .undefined(name: name.displayable)
      }
    }()
  }
}

extension ResourceFieldSpecification: Hashable {

  public static func == (
    _ lhs: ResourceFieldSpecification,
    _ rhs: ResourceFieldSpecification
  ) -> Bool {
    lhs.path == rhs.path
      && lhs.content == rhs.content
      && lhs.required == rhs.required
      && lhs.name == rhs.name
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.path)
  }
}

extension ResourceFieldSpecification.Content: Hashable {}

extension ResourceFieldSpecification {

  public var validator: Validator<JSON> {
    .init(validate: self.validate(_:))
  }

  internal func validate(
    _ json: JSON  // assuming this is proper nested element if needed
  ) throws {
    guard json != .null
    else {
      if self.required {
        throw
          InvalidResourceField
          .required(
            specification: self,
            path: self.path,
            value: json
          )
      }
      else {
        return  // NOP - not required and null -> valid
      }
    }

    switch self.content {
    case .string(let minLength, let maxLength):
      guard let stringValue: String = json.stringValue
      else {
        throw
          InvalidResourceField
          .type(
            specification: self,
            path: self.path,
            value: json
          )
      }

      if self.required, stringValue.isEmpty {
        throw
          InvalidResourceField
          .required(
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

      if let minLength, stringValue.count < minLength {
        throw
          InvalidResourceField
          .minimumLength(
            of: minLength,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

      if let maxLength, stringValue.count > maxLength {
        throw
          InvalidResourceField
          .maximumLength(
            of: maxLength,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

    case .int(let min, let max):
      guard let intValue: Int = json.intValue
      else {
        if self.required, json.stringValue?.isEmpty ?? false {
          throw
            InvalidResourceField
            .required(
              specification: self,
              path: self.path,
              value: json
            )
        }
        else {
          throw
            InvalidResourceField
            .type(
              specification: self,
              path: self.path,
              value: json
            )
        }
      }

      if let min, intValue < min {
        throw
          InvalidResourceField
          .minimum(
            of: min,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

      if let max, intValue > max {
        throw
          InvalidResourceField
          .maximum(
            of: max,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

    case .double(let min, let max):
      guard let doubleValue: Double = json.doubleValue
      else {
        if self.required, json.stringValue?.isEmpty ?? false {
          throw
            InvalidResourceField
            .required(
              specification: self,
              path: self.path,
              value: json
            )
        }
        else {
          throw
            InvalidResourceField
            .type(
              specification: self,
              path: self.path,
              value: json
            )
        }
      }

      if let min, doubleValue < min {
        throw
          InvalidResourceField
          .minimum(
            of: min,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

      if let max, doubleValue > max {
        throw
          InvalidResourceField
          .maximum(
            of: max,
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

    case .stringEnum(let values):
      guard let stringValue: String = json.stringValue
      else {
        throw
          InvalidResourceField
          .type(
            specification: self,
            path: self.path,
            value: json
          )
      }

      if !values.contains(stringValue) {
        throw
          InvalidResourceField
          .notListed(
            specification: self,
            path: self.path,
            value: json
          )
      }  // else NOP

    case .structure(let structure):
      for fieldSpecification in structure {
        let fieldJSON: JSON = json[dynamicMember: fieldSpecification.name.rawValue]
        try fieldSpecification
          .validate(fieldJSON)
      }
    }
  }

  internal func specification(
    for path: Resource.FieldPath
  ) -> ResourceFieldSpecification? {
    if self.path == path {
      return self
    }
    else if case .structure(let fields) = self.content {
      for field in fields {
        if let match: Self = field.specification(for: path) {
          return match
        }
        else {
          continue
        }
      }
      return .none
    }
    else {
      return .none
    }
  }
}

extension ResourceFieldSpecification {

  internal struct Sorting: SortComparator {

    internal typealias Compared = ResourceFieldSpecification

    internal var order: SortOrder = .forward {
      willSet {
        guard case .forward = newValue
        else { unimplemented("Unsupported ordering") }
      }
    }

    internal func compare(
      _ lhs: ResourceFieldSpecification,
      _ rhs: ResourceFieldSpecification
    ) -> ComparisonResult {
      guard case .forward = self.order
      else { unimplemented("Unsupported ordering") }
      // resource fields should be sorted however
      // there is no corrent way of sorting it
      // nor ordering is provided by type description
      // for current partially hardcoded support
      // of resource types we are sorting fields based
      // on its paths only
      switch (lhs.path, rhs.path) {
      case (\Resource.meta.name, _):
        return .orderedAscending

      case (_, \Resource.meta.name):
        return .orderedDescending

      case (\Resource.meta.username, _):
        return .orderedAscending

      case (_, \Resource.meta.username):
        return .orderedDescending

      case (\Resource.meta.uri, _):
        return .orderedAscending

      case (_, \Resource.meta.uri):
        return .orderedDescending

      case (\Resource.secret, _):
        return .orderedAscending

      case (_, \Resource.secret):
        return .orderedDescending

      case (\Resource.secret.password, _):
        return .orderedAscending

      case (_, \Resource.secret.password):
        return .orderedDescending

      case (\Resource.secret.description, _):
        return .orderedAscending

      case (_, \Resource.secret.description):
        return .orderedDescending

      case (\Resource.meta.description, _):
        return .orderedAscending

      case (_, \Resource.meta.description):
        return .orderedDescending

      case _:  // we don't know how to / don't want to sort anything else
        return .orderedSame
      }
    }
  }
}

extension ResourceFieldSpecification.Content {

  public static let totp: Self = .structure([
    .init(
      path: \.secret.totp.algorithm,
      name: "algorithm",
      content: .stringEnum(
        values: [
          "SHA1",
          "SHA256",
          "SHA512",
        ]
      ),
      required: true,
      encrypted: true
    ),
    .init(
      path: \.secret.totp.secret_key,
      name: "secret_key",
      content: .string(
        minLength: .none,
        maxLength: 1024
      ),
      required: true,
      encrypted: true
    ),
    .init(
      path: \.secret.totp.digits,
      name: "digits",
      content: .int(
        min: 6,
        max: 8
      ),
      required: true,
      encrypted: true
    ),
    .init(
      path: \.secret.totp.period,
      name: "period",
      content: .int(
        min: 1,
        max: .none
      ),
      required: true,
      encrypted: true
    ),
  ])
}
