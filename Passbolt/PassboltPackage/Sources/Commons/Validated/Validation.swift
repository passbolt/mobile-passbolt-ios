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

public struct Validation<Subject> {

  public let keyPath: PartialKeyPath<Subject>
  private let validation: (inout Subject) -> TheError?
}

extension Validation {

  public static func validating<Value>(
    _ keyPath: WritableKeyPath<Subject, Validated<Value>>,
    with validator: Validator<Value>
  ) -> Self {
    .init(
      keyPath: keyPath,
      validation: { (subject: inout Subject) in
        subject[keyPath: keyPath] = validator(subject[keyPath: keyPath].value)
        return subject[keyPath: keyPath].error
      }
    )
  }

  @discardableResult
  public func validate(
    _ subject: inout Subject
  ) -> TheError? {
    self.validation(&subject)
  }
}

extension Validation {

  internal static func combine<Value>(
    _ validations: Self...,
    for keyPath: WritableKeyPath<Subject, Validated<Value>>
  ) -> Self {
    Self.combine(
      validations,
      for: keyPath
    )
  }

  internal static func combine<Value>(
    _ validations: any Sequence<Self>,
    for keyPath: WritableKeyPath<Subject, Validated<Value>>
  ) -> Self {
    let validations: Array<Self> = validations.filter { $0.keyPath == keyPath }
    return .init(
      keyPath: keyPath,
      validation: { (subject: inout Subject) in
        for validation: Self in validations {
          validation.validate(&subject)
          // don't override, use the first error
          if let error = subject[keyPath: keyPath].error {
            return error
          }
          else {
            continue
          }
        }

        return .none
      }
    )
  }
}