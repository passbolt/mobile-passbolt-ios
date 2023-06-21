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

public final class AnyViewStateSource<ViewState>: ViewStateSource
where ViewState: Sendable {

  public var objectWillChange: ObservableObjectPublisher { self.source.objectWillChange }
  public var updates: Updates { self.source.updates }

  public let source: any ViewStateSource<ViewState>

  public init<Source>(
    erasing source: Source
  ) where Source: ViewStateSource, Source.ViewState == ViewState {
    self.source = source
  }

  @MainActor public var state: ViewState {
    @inlinable get { self.source.state }
  }

  @inlinable
  @MainActor public func binding<Value>(
    to keyPath: WritableKeyPath<ViewState, Value>
  ) -> Binding<Value> {
    self.source.binding(to: keyPath)
  }

  @inlinable
  @MainActor public func forceUpdate() {
    self.source.forceUpdate()
  }
}

extension ViewStateSource {

  public func asAnyViewStateSource() -> AnyViewStateSource<ViewState> {
    self as? AnyViewStateSource<ViewState> ?? .init(erasing: self)
  }
}
