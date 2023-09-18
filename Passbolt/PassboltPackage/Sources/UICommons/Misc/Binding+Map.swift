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

extension Binding {

  public func some<Wrapped>() -> Binding<Bool>
  where Value == Optional<Wrapped> {
    .init(
      get: { self.wrappedValue != nil },
      set: { (newValue: Bool) in
        guard !newValue else { return }  // can't set not nil
        self.wrappedValue = .none
      }
    )
  }

  public func map<NewValue>(
    get: @escaping (Value) -> NewValue,
    set: @escaping (NewValue) -> Value
  ) -> Binding<NewValue> {
    .init(
      get: {
        get(self.wrappedValue)
      },
      set: { (newValue: NewValue) in
        self.wrappedValue = set(newValue)
      }
    )
  }

  public func filterMapOptional() -> Binding<Optional<Value>> {
    .init(
      get: { self.wrappedValue },
      set: { (newValue: Optional<Value>) in
        guard let newValue else { return }
        self.wrappedValue = newValue
      }
    )
  }
}
