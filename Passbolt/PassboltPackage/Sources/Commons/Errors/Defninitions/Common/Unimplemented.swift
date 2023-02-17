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

import Localization

public struct Unimplemented: TheError {

  public static func error(
    _ message: StaticString = "Unimplemented",
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          message,
          file: file,
          line: line
        )
      ),
      displayableMessage: .localized(key: .genericError)
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
}

@Sendable public func unimplemented(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> Never {
  Unimplemented
    .error(
      file: file,
      line: line
    )
    .recording(message, for: "message")
    .asFatalError()
}

@Sendable public func unimplemented0<R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable () -> R {
  {
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented1<A1, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1) -> R {
  { _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented2<A1, A2, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2) -> R {
  { _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented3<A1, A2, A3, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3) -> R {
  { _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented4<A1, A2, A3, A4, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4) -> R {
  { _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented5<A1, A2, A3, A4, A5, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4, A5) -> R {
  { _, _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented6<A1, A2, A3, A4, A5, A6, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4, A5, A6) -> R {
  { _, _, _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented7<A1, A2, A3, A4, A5, A6, A7, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4, A5, A6, A7) -> R {
  { _, _, _, _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented8<A1, A2, A3, A4, A5, A6, A7, A8, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4, A5, A6, A7, A8) -> R {
  { _, _, _, _, _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}

@Sendable public func unimplemented9<A1, A2, A3, A4, A5, A6, A7, A8, A9, R>(
  _ message: String = "Unimplemented",
  file: StaticString = #fileID,
  line: UInt = #line
) -> @Sendable (A1, A2, A3, A4, A5, A6, A7, A8, A9) -> R {
  { _, _, _, _, _, _, _, _, _ in
    Unimplemented
      .error(
        file: file,
        line: line
      )
      .recording(message, for: "message")
      .asFatalError()
  }
}
